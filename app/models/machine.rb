
class Machine < ActiveRecord::Base
  has_many :jobs
  belongs_to :job
  validates :name, :port, :nickname, :presence => true
  validates_uniqueness_of :nickname, :case_sensitive => false, :scope => [ :name, :port]
  default_scope :order => 'name ASC, port ASC'
  scope :active, where(:deleted_at => nil)
  attr_reader :message
  attr_accessor :user, :agent_info

  def Machine.reset_env_lists
    Rails.logger.info "Resetting machine agent lists"
    Machine.all.each do |m|
      m.environments = nil
      m.save
    end
  end

  def env_list
    unless self.environments
      machs = Machine.active
      allowed_envs = {}
      allowed_machs = {}
      machs.each do |m|
        allowed_envs[m.nickname] = []
        Environment.active.each do |e|
          allowed_machs[e.name] = [] unless allowed_machs[e.name]
          if e.agents.nil? or m.nickname =~ /#{e.agents}/
            allowed_machs[e.name].push(m.nickname)
            allowed_envs[m.nickname].push(e.name)
          end
        end
      end
      env_order = allowed_machs.sort {|a,b| a[1].size <=> b[1].size }.collect{|a| a[0]}
      sn = self.nickname
      if allowed_envs[self.nickname]
        envs = env_order.delete_if {|e| !allowed_envs[self.nickname].include?(e)}
        self.environments = envs.join(',')
      else
        self.environments = ''
      end
      save
    end
    self.environments
  end

  # Returns mach_name/[cur/]mach_nickname
  def url(insert = nil)
    insert && insert = "#{insert}/"
    # Single webserver serving each agent machine name via an alias
    webserver = Occ::Application.config.occ['results_webserver'] and
      return "http://#{webserver}/#{name.sub(/\..*/,'')}/#{insert}#{nickname}/"
    # Each agent has its own webserver
    "http://#{name}/#{insert ? 'oats/r' : 'oats/a'}/#{nickname}/"
  end

  # Ask machine for status and persist actual latest status
  # Restarts machine with requested repo if status is dead.
  # Returns immediately unless
  def status(repo = nil, verify = nil)
    old_status = self.persisted_status
    new_status = get_status(true)
    @message = '' unless @message
    max_dead_seconds = 10
    if %w(dead starting).include?(new_status) and old_status == new_status  # Restart only if you see dead status twice
      delta = Time.new - updated_at
      @message << "Machine [#{self.nickname}] has been dead for [#{delta.to_i}] seconds. "
      if delta > max_dead_seconds
        agent_log = get_agent_log
        if agent_log
          lines = agent_log.split "\r"+$/
          if lines.last == @agent_log_last_lines
            @message << " Will not restart the agent since last line of log did not change after previous restart:\n #{lines.last}."
          else
            if RUBY_PLATFORM =~ /(mswin|mingw)/  and lines.last !~ / \d\d:\d\d:\d\d \[RS/
              # long running low level Ruby ops blocks eventmachine on Windows
              @message << " Will not restart the agent on Windows since since last line of log is:\n #{lines.last}"
            else
              @message << "Restarted agent on agent #{self.nickname} "
              @agent_log_last_lines = lines.last
              start(repo, verify)
            end
          end
        else
          @message << " Will not restart the agent since the agent log is not accessible. "
        end
      else
        @message << " Will not restart the agent since it has not been #{max_dead_seconds} seconds yet. "
      end
      Rails.logger.info @message unless @message == ''
    end
    @message = nil if @message == ''
    return new_status
  end

  def agent_log_url
    # logfile may be empty right after start, since we don't wait the response and refresh quickly.
    # dated file will show up upon refresh.
    url+'agent_logs/'+(%w(dead starting).include?(self.persisted_status) ? 'agent.log' : (logfile ? logfile : ''))
  end

  def get_agent_log
    if Occ::Application.config.occ['results_webserver']
      web_host = Occ::Application.config.occ['results_webserver']
    else
      web_host = name
    end
    murl = agent_log_url
    begin
      resp = Net::HTTP.new(web_host, 80).get(murl)
      return resp.body if resp.code == '200'
    rescue
      Rails.logger.warn $!.to_s
      @message << "#{$!}, after issuing get request to [#{murl}]"
      Rails.logger.warn @message
      return nil
    end
  end

  def start(repo = nil, verify = nil)
    shutdown(repo)
    self.persisted_status = 'starting'
    self.job = nil
    self.save
    Rails.logger.info "Attempting to start #{name}"
    agent(repo ? repo : nil)
    return unless verify
    max_secs = 8
    sleep init_secs = 2
    stat = nil
    for c in init_secs..max_secs do
      sleep( RUBY_PLATFORM =~ /(mswin|mingw)/ ? 4 : 1 ) # W7 is much slower
      stat = get_status(true)
      break unless stat == 'dead'
    end
    Rails.logger.info "Gave up on starting machine #{self.name}. It did not respond for #{max_secs} seconds." \
      if c == max_secs
  end

  def shutdown(repo=nil)
    msg = "Attempting to stop #{self.name}"
    request = { :command => 'shutdown' }
    if repo
      msg += " because need repo version #{repo}"
      request[:repo] = repo
    end
    Rails.logger.info msg
    3.times { break if issue_erequest(request) == 'dead'; sleep 1 }
    agent(true) unless self.persisted_status == 'dead'
  end

  # Return messages in an array
  def Machine.refresh(user = nil)
    Machine.active.collect { |e| e.user = user if user; e.status; e.message  }
  end

  def undelete
    #    self.update_attributes(:deleted_at => nil)
    self.deleted_at = nil
    self.get_status(true) # update status and persist
  end

  # start/stop request
  def perform(erequest, stop_jobs_list = nil)
    if erequest.instance_of?(Erequest)
      #      Rails.logger.info "Performing #{erequest.command} on #{nickname}"
      agent_request = {:command => erequest.command, :id => erequest.id,
        :user => erequest.user.email, :repo => erequest.repo_version }
      agent_request[:stop_jobs] = stop_jobs_list if stop_jobs_list
    else
      Rails.logger.info "Job erequest to perform must be of must be of Erequest class."
    end
    issue_erequest(agent_request)
  end

  def get_results(job)
    #    return nil unless self.alive?
    #    return nil if status == 'dead'  # Restarts if dead # Can't use it since it gives exta status check
    req = { :command => 'results' , :jobid => job.id, :list => job.list_name}
    res = issue_erequest(req)
    if persisted_status == 'dead'
      status(nil, true)
      res = issue_erequest(req)
    end
    self.job_id = job.id
    return res
  end

  # Return persisted current status. First update status if do_poll is true
  # Return integer jobid for busy
  def get_status(do_poll = false)
    if do_poll
      stat = issue_erequest({ :command => 'status' })
    else
      stat = self.persisted_status
    end
    jobid = stat.to_i
    stat = jobid unless jobid == 0
    return stat
  end

  private

  def alive?(poll = false)
    return (get_status(poll) != 'dead')
  end

  # No exceptions, but returns one of four status strings
  def issue_erequest(agent_request)
    agent_request[:occ_host] = Occ::Application.config.occ['server_host']
    agent_request[:occ_port] = Occ::Application.config.occ['server_port']
    agent_request[:info] = agent_info if agent_info
    agent_request[:user] ||= self.user.email if self.user
    #    agent_request[:password] = password
    conn = nil
    stat = 'error'
    begin
      # load 'rclient.rb' # debug
      EventMachine::run {
        conn = EventMachine::connect name, port, OatsAgent::Rclient, nickname, agent_request
        # Need to terminate effort in case host name or else is bad.
        EM.add_timer(Occ::Application.config.occ['timeout_waiting_for_agent']) {conn.close_connection }
      }
    rescue Exception => exc
      Rails.logger.info "ERROR: #{exc.message}"
      #      raise exc
      Rails.logger.info "ERROR: #{exc.backtrace.join("\n")}"
    end
    if conn
      resp = conn.response
      if resp
        if resp[:is_busy]
          stat = resp[:is_busy]
        else
          stat = 'waiting'
        end
      else
        stat = 'dead'
      end
    else
      resp = { :error => "#{exc.message if exc}"}
    end
    self.persisted_status = stat
    save self
    if agent_request[:command] == 'results'
      unless resp
        Rails.logger.warn "Machine #{self.name} did not respond to erequest #{agent_request.inspect}"
      end
      return resp
    else
      return stat
    end
  end

  
  def agent(option = nil)
    options = { 'nickname' => nickname, 'port' => port }
    options['user' ] = user.email if user
    if option
      if option.instance_of? String
        options['repository_version'] = repo
      else
        options['kill_agent'] = true
      end
    end
    Rails.logger.info "Initiate OatsAgent request: #{options.inspect}"
    OatsAgent.spawn(options)
  end
  
end
