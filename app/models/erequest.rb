class Erequest < ActiveRecord::Base
  #attr_reader :is_elapse_ended
  has_many :jobs
  belongs_to :user
  has_many :stopped_jobs, :class_name =>'Jobs', :foreign_key =>"stop_erequest_id"
  belongs_to :environment  # Environment to start or stop
  #has_one :environment  # Last start erequest referenced by the environment
  validates :environment, :presence => true
  validates :repo_version, :presence => true, :if => "command == 'start'"
  validates :user, :presence => true
  default_scope :order => 'id desc', :limit => 100

  before_validation :repo_version_update

  def finish_str
    end_string = ''
    ft = self.finished_time
    if ft
      end_string = ft.strftime(Job::DF)
    elsif self.stop_erequest
      if self.stop_erequest.command == 'stop'
        end_string = 'Stopped'
      else
        end_string = 'Unfinished'
      end
    end
    return end_string
  end

  def job_summary
    Erequest.job_summary(self.jobs)
  end

  def Erequest.job_summary(req_jobs)
    total_tests = passed_tests = failed_tests = skip_tests = started_jobs = 0
    tests_ended = true
    browser = ''
    build = nil
    diff = []
    req_jobs.each do |job|
      if job.tests and not job.tests.empty? and job.total
        total_tests += job.total
        tests_ended &&= job.is_finished
        passed_tests += job.pass
        failed_tests += job.fail
        skip_tests += job.skip
        diff = diff + job.bugs_failed
      end
      browser = job.browser if job.browser
      if job.build_version
        unless build
          build = job.build_version
        else
          job.build_version.each_pair do |name, val|
            if build[name]
              build[name] += '+' unless build[name] == val or build[name][-1,1] == '+' or build[name] == ''
            else
              build[name] == val
            end
          end
        end
      end
      started_jobs += (job.started_at ? 1 : 0)
    end
    total_jobs = req_jobs.size
    tests_ended = false unless started_jobs == total_jobs
    [ diff, build, browser, total_jobs == 0 ? '' : (started_jobs.to_s + '/'+ total_jobs.to_s),
      total_tests == 0 ? '' : (total_tests.to_s + (tests_ended ? '' : '+')) ] +
      [passed_tests, failed_tests, skip_tests ].map{|i| i == 0 ? '' : i.to_s}
  end

  def elapsed
    if (self.created_at and self.finished_time)
      elapsed = (self.finished_time - self.created_at).to_i
      is_elapse_ended = self.jobs.find_by_finished_at(nil).nil?
      #      if self.stop_erequest
      mach_count = self.jobs.collect{|job| job.machine}.uniq.size
    else
      elapsed = {}
      is_elapse_ended = true
      self.jobs.each do |job|
        next unless job.machine
        elapsed[job.machine] = 0 unless elapsed[job.machine]
        if job.elapsed
          elapsed[job.machine]+= job.elapsed
          is_elapse_ended &&= job.is_finished
        else
          is_elapse_ended = false
        end
      end
      mach_count = elapsed.size
      elapsed = elapsed.values.max
    end
    if elapsed == 0
      el_str = ''
    else
      el_str = elapsed.to_s + (is_elapse_ended ? '' : '+')
      el_str += ':' + mach_count.to_s unless mach_count == 0
    end
  end

  def finished_time
    ft = self.finished_at
    return ft if ft and ft >= self.created_at
    return nil if self.jobs.exists?(:is_results_final => false)
    ft = self.jobs.maximum('finished_at')
    unfinished_jobs = self.jobs(:is_results_final => false, :finished_at => nil)
    unless unfinished_jobs.empty?
      unfinished_jobs.each do |ufj|
        ufj_ft = ufj.finished_time(true)
        next unless ufj_ft
        ft = ufj_ft if ft.nil? or ufj_ft > ft
      end
    end
    return nil unless ft
    ft = nil if ft and ft < self.created_at
    self.finished_at = ft
    self.save
    return ft
  end

  # Returns the erequest that stopped self
  def stop_erequest
    sql = "select job.* from erequests as erequest inner join jobs as job on erequest.id = job.erequest_id
where erequest_id = #{self.id} and job.stop_erequest_id is not null;"
    stopped_job = Job.find_by_sql(sql).first
    return stopped_job && stopped_job.stop_erequest
  end

  # Stops outstanding jobs for self, which is a start request
  def stop
    stop_erequest = self.environment.erequests.create(:command => 'stop')
    #    sql = "select * from jobs where erequest_id = #{self.id} and stop_erequest_id IS NULL and finished_at IS null;"
    jobs = Job.find_all_by_erequest_id_and_stop_erequest_id_and_finished_at(self.id,nil,nil)
    stop_erequest.stop_jobs jobs
  end

  # Stop indicated jobs, using self, which is a stop request
  def stop_jobs(js)
    machines_to_stop =  {}
    jobs_to_stop = {}
    jobs_not_started = []
    js.each do |j|
      logger.warn "job id to stop is: #{j.id}"
      j.stop_erequest = self
      if j.machine
        nam = j.machine.nickname
        machines_to_stop[nam] = j.machine unless j.machine.deleted_at
        jobs_to_stop[nam] = [] unless jobs_to_stop[nam]
        jobs_to_stop[nam] << j.id
      else
        jobs_not_started << j
      end
      j.save
    end
    jobs_not_started.each do |j| # In case any more got picked up
      if j.machine and j.machine.deleted_at.nil?
        nam = j.machine.nickname
        machines_to_stop[nam] = j.machine
        jobs_to_stop[nam] = [] unless jobs_to_stop[nam]
        jobs_to_stop[nam] << j.id
      end
    end
    stop_statuses_hash = act_on_machines(machines_to_stop.values,jobs_to_stop)
    message = gather_message(stop_statuses_hash)
    if message
      if self.message
        self.message += message
      else
        self.message = message
      end
      self.save
    end
  end

  # Recreate job queues and restart machines if the command was a start/restart
  def create_jobs_for_env(env,env_list, run_options = nil)
    jobs = []
    env_list.each do |list|
      job = self.jobs.create!(:list_id => list.id, :environment_name => env.name,
        :list_name => list.name, :run_options => run_options)
      #      job.save # Somehow run_options are not set without this save
      jobs << job
    end
    return jobs
  end

  def start_machines
    # First restart all dead machines with the requested repo_version
    # consequently these will be the ones first ones asking for jobs
    Machine.find_all_by_deleted_at_and_persisted_status(nil,'dead').each do |m|
      m.user = self.user
      m.status(repo_version, true)
    end
    # Now consider all the available machines
    machines = Machine.find_all_by_deleted_at_and_persisted_status(nil,'waiting')
    # Minus the ones not allocated to the needed environment
    machines.delete_if { |item| !item.env_list.split(',').include?(self.environment.name) }
    # Limit the number of additional machines awakened to the number of outstanding jobs needed at this time
    cnt = Job.find_all_by_stop_erequest_id_and_machine_id(nil,nil).count
    start_statuses_hash = act_on_machines(machines[0...cnt])
    if start_statuses_hash.empty?
      message = "There are no available machines."
    else
      message = gather_message(start_statuses_hash, message)
    end
    if message
      old_msg = self.message
      if old_msg
        self.message = message + old_msg
      else
        self.message = message
      end
      self.save
    end
    #    Erequest.update(self.id, :message => message) if message
  end

  private

  def gather_message(start_status,message = nil)
    return nil unless start_status
    message = (message ? message + '<br>' : '') +
      "No response. Could not #{self.command}: #{start_status['dead'].inspect}. " if start_status['dead']
    message = (message ? message + '<br>' : '') +
      "Error during processing. Could not #{self.command} #{start_status['error'].inspect} " if start_status['error']
    return message
  end

  def act_on_machines(machine_list,jobs_to_stop = nil)
    mach_stat = {}
    machine_list.each do |machine|
      #      jobs_to_stop.inspect
      begin
        nam = machine.nickname
        stop_jobs_list = jobs_to_stop[nam] if jobs_to_stop
        stat = machine.perform(self, stop_jobs_list)
        if mach_stat[stat]
          mach_stat[stat] << nam
        else
          mach_stat[stat] = [ nam ]
        end
      end
    end
    return mach_stat
  end

  def repo_version_update
    return if repo_version or command != 'start'
    Dir.chdir(Occ::Application.config.occ['dir_tests']) do
      try_count = 3
      begin
        cmd = nil
        Timeout::timeout 5 do
          if File.directory?('.git')
            if ENV['OATS_TESTS_GIT_REPOSITORY']
              origin = ENV['OATS_TESTS_GIT_REPOSITORY'] # || 'origin'
              #        repo = `git remote -v`.chomp.split("\n").grep(/fetch/).first.sub(/origin\t(.*) \(fetch\)/,'\1')
              cmd = "git pull #{origin} master 2>&1"
              Rails.logger.info "Issuing git cmd: #{cmd}"
              msg = `#{cmd}`.chomp
              Rails.logger.info msg
              unless $?.to_i == 0
                self.message = "Error during [#{cmd}]: #{msg}"
                return nil
              end
            # else  # Unset this to test the code when running w/o git access
#              msg = "Undefined OATS_TESTS_GIT_REPOSITORY"
#              self.message = msg
#              Rails.logger.info msg
#              return nil
            end
            cmd = 'git rev-list master -1'
            git_rev = `#{cmd}`.chomp
            unless $?.to_i == 0
              self.message = "Error during [#{cmd}]: #{git_rev}"
              return nil
            end
            Rails.logger.info "Last Git Commit: #{git_rev}"
            self.repo_version = git_rev
          else
            repo = Occ::Application.config.occ['svn_repository']
            cmd = "svn info #{repo}"
            Rails.logger.info "Issuing svn cmd: #{cmd}"
            svn_out = `#{cmd}`
            Rails.logger.info svn_out
            self.repo_version = svn_out.chomp.split("\n").grep(/Last Changed Rev:/).collect{|i| i.sub(/.* /,'')}.max
          end
        end
      rescue Timeout::Error
        try_count -= 1
        msg = "Timed out waiting for [#{cmd}]. Retries left: #{try_count}"
        Rails.logger.info msg
        if try_count > 0
          sleep 2
          retry
        end
        self.message = msg
        return Time.now.to_i
      end
    end
  end
end