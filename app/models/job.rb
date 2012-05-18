class Job < ActiveRecord::Base
  DF = '%m/%d/%H:%M:%S'
  belongs_to :erequest
  belongs_to :stop_erequest, :class_name => "Erequest",
    :foreign_key =>"stop_erequest_id"
  belongs_to :list
  belongs_to :machine
  has_many :jobtests
  validates :erequest, :presence => true
  validates :list, :presence => true
  default_scope :order => 'id desc', :limit => 500
  # Use for migrating old jobs table
  #  default_scope :conditions => "results_status is null and yresults is not null", :order => 'id desc', :limit => 5000

  def is_finished
    self.finish_str unless @is_finished
    return @is_finished
  end

  def started_str
    return @start_str if @start_str
    if results_start_time
      @start_str = Time.at(results_start_time).strftime(DF)
    elsif self.start_time
      @start_str =  Time.at(self.start_time).strftime(DF)
    elsif self.started_at
      @start_str = self.started_at.strftime(DF)
    end
    return @start_str
  end

  # Same as finished_time, but Time is formatted as string
  def finish_str
    ft = self.finished_time
    #    Rails.logger.info "ft #{ft}"
    return ft.strftime(DF) if ft.kind_of?(Time)
    return ft
  end

  # Returns nil, or Time, or String: Cancelled, Died, Stopped
  def finished_time(is_time_only = false)
    return @finish_time if @finish_time
    if tests && stop_oats
      fin_time = 'Stopped'
    elsif tests and results_end_time
      #      @is_finished = (end_time and finished_at)
      @is_finished = end_time
      fin_time = Time.at(results_end_time)
    elsif (self.end_time)
      @is_finished = true
      fin_time = Time.at(self.end_time)
    elsif self.stop_erequest
      fin_time = 'Stopped'
    elsif self.finished_at
      @is_finished = true unless tests && stop_oats
      fin_time = self.finished_at
    elsif self.is_results_final
      fin_time = 'Died'
    end
    @finish_time = fin_time
    return nil if is_time_only and ! fin_time.instance_of?(Time)
    return @finish_time
  end


  def elapsed_str
    el = self.elapsed
    return '' unless el # and el != 0 # Display zero elapsed times as zero
    return el.to_s + (self.is_finished ? '' : '+')
  end

  def elapsed
    if self.started_at
      if self.end_time
        elapsed = self.end_time - self.start_time
      elsif tests and results_end_time
        elapsed = results_end_time - results_start_time
      elsif self.finished_at
        elapsed = (self.finished_at - self.started_at).to_i
      elsif self.is_results_final and self.tests and not self.tests.empty?
        elapsed = 0
        self.tests and self.tests.each do |tst|
          break unless tst['end_time'] and tst['start_time']
          elapsed += tst['end_time'] - tst['start_time']
        end
      elsif self.finish_str.nil?
        elapsed = (Time.now - self.started_at).to_i
      end
    end
    return elapsed
  end

  # Inputs relative path, returns URL path in archived jobid or cur
  # path nil assumes <cumulative-results>.html.  Returns nil in case of error or no machine
  def url(path = nil)
    #    return @url if @url # Can't persist into instance, this return varies with input
    mach = machine
    return nil unless mach
    #    return nil unless results_status
    #    return nil if %w(Missing, Error).include? results_status
    are_results_archived = ( results_status == 'Archived' )
    unless path
      #
      if are_results_archived
        list_name = self.list_name
        if File.extname(list_name) == '.yml'
          html_name =  File.basename(list_name, '.*') + '-' + environment_name
        else
          html_name = 'results'
        end
        path = html_name + '.html'
      else
        if tests # and testlist.total # don't need the first one finished for this
          path = ''
        else
          @url = nil ; return @url
        end
      end
    end
    if are_results_archived
      @url = mach.url + "#{runid || id}/" + path
    else
      @url = mach.url('cur') + path
    end
    return @url
  end

  def process_oats_results
    return if self.is_results_final or @process_oats_results # and false # For debug
    @process_oats_results = true
    mach = self.machine
    unless mach # Can not have results w/o machine
      @get_results_err = "Is not yet picked up."
      return
    end
    resp = mach.get_results(self)
    unless resp
      Rails.logger.warn "Nil response for job #{id} from #{mach.nickname}"
      @get_results_err = "Received no response for job"
      return
    end
    new_results = resp[:oats_info]
    unless new_results
      if resp[:is_busy]
        @get_results_err = "No results info is available yet."
        Rails.logger.warn "[DEBUG] #{@get_results_err}"
        return
      end
      Rails.logger.warn "Received empty oats_info for job #{self.id} in #{mach}"
      @get_results_err = "Job produced no results."
    end
    @get_results_err = "Missing results" if new_results['results_status'] == 'Missing'
    if @get_results_err
      self.results_error = @get_results_err
      self.is_results_final = true
      self.save
      return
    end
    unless new_results['jobid']
      @get_results_err = 'oats_info is missing jobid'
      Rails.logger.warn "[DEBUG] #{@get_results_err}"
      return
    end

    msg = "Received results for jobid #{new_results['jobid']} from #{mach.nickname}"
    if new_results['jobid'] == id
      Rails.logger.debug msg
    else
      @get_results_err = "#{msg} while expecting #{id}"
      Rails.logger.warn "ERROR: #{@get_results_err}"
      return
    end
    mach.job = self
    mach.save

    if %w(Error Early).include? new_results['results_status']
      @get_results_err = new_results['results_status']
      if new_results['results_status'] == 'Error'
        Rails.logger.warn("[DEBUG] Encountered #{@get_results_err} in received results." )
        Rails.logger.error(new_results['error_message']) if new_results['error_message']
      end
    end
    self.is_results_final = %w(Archived Error Missing).include?(new_results['results_status']) #  Early Partial Current

    if new_results
      testlist = new_results['test_files']
      if testlist
        self.tests_json = testlist['tests'].to_json if testlist['tests']
        self.total = testlist['total']
        self.skip = testlist['skip']
        self.pass = testlist['pass']
        self.fail = testlist['fail']
        self.start_time = testlist['start_time']
        self.end_time = testlist['end_time']
      end
      if new_results['results_error'].nil? and testlist.nil? and
          new_results['results_status'] == 'Archived'
        new_results['results_error'] = 'Archived run with no results.'
      end
      self.results_error = new_results['results_error']
      # Start and end times reported by main and driver in Oats.context
      self.results_end_time = new_results['end_time']
      self.results_start_time = new_results['start_time']
      self.stop_oats = new_results['stop_oats']
      self.results_status = new_results['results_status']
      self.build_version_json = new_results['build_version'].to_json if new_results['build_version']
      self.browser = new_results['browser']
    end

    self.save if self.is_results_final
  end

  def results_error_msg
    return @get_results_err if @get_results_err
    return results_error
  end
  def tests
    return @tests if @tests # Don't return nil for [] tests so that empty results can be indicated ??
    process_oats_results unless self.is_results_final
    @tests = tests_json ? JSON.parse(tests_json) : nil
    @tests = nil if @tests and @tests.empty?
    @tests
  end
  def build_version
    return @build_version if @build_version
    process_oats_results unless build_version_json
    @build_version = build_version_json ? JSON.parse(build_version_json) : nil
  end

  def archived?
    results_status == 'Archived'
  end

  def repo_svn?
    repo_version.size < 7
  end


  def Job.uuid()
    sql = "SELECT UUID()"
    record = connection.select_one(sql)
    return record['UUID()']
  end

  # Receive http://localhost:3000/jobs/nxt?nickname=latasoy_1&machine=latasoy-mp.local&port=3011&logfile=agent.log&jobid=10&repo=1234
  # Has jobid if finished previous, has repo if known
  # Start by: agent -n la-macpro_3 -p 3030
  def Job.nxt(params)
    params[:machine].downcase!
    params[:nickname].downcase!
    mach = Machine.find_by_nickname(params[:nickname])
    unless mach
      mach = Machine.find_or_initialize_by_name_and_port(params[:machine],params[:port])
      mach.nickname = params[:nickname]
      Machine.reset_env_lists
    else
      mach.port = params[:port]
    end
    mach.name = params[:machine]
    mach.logfile = params[:logfile]
    mach.repo_version = params[:repo]
    mach.persisted_status = 'waiting'
    mach.deleted_at = nil
    mach.password ||= Job.uuid
    mach.save!
    if params[:jobid]  # Reporting a previous job is finished.
      job = Job.find(params[:jobid])
      job.machine = mach
      finish_time = Time.now
      job.finished_at = finish_time
      if job.started_at and finish_time < job.started_at
        msg= "Unexpected job finish_time #{finish_time} is smaller than started_at #{job.started_at}"
        job.results_error = job.results_error ? (job.results_error + msg) : msg
        Rails.logger.warn job.results_error
      end
      #      unless job.get_results # Succeeded in receiving results. Maybe should rerun if not successful also.
      if job.tests and not job.list.rerun and not job.erequest.environment.rerun
        failed = job.new_bug_cnt
        if failed > 0
          j = Job.where("id != #{job.id} and list_name = '#{job.list_name}' and
            environment_name = '#{job.environment_name}' and stop_erequest_id is null
            and is_results_final is not null").first
          if j and j.tests # Sometimes receiving nil testlist, sometimes it fails the first time j is nil
            prev_fail = j.new_bug_cnt
            Rails.logger.info "[DEBUG] Previous failure count for job #{j.id} list #{j.list_name} is #{prev_fail} "
            if failed > prev_fail
              Rails.logger.info "[DEBUG] Will rerun job #{j.id} list #{j.list_name} since current fail count is #{failed}"
              env = job.erequest.environment
              req = env.erequests.create!(:command => 'start', :user => job.erequest.user, :repo_version => job.repo_version)
              req.save
              nbs = nil # job.new_bugs.collect { |idx| File.basename(job.tests[idx]['id']) }.join(',')
              # todo: Pass the appropriate YAML option for test restriction once it is implemented
              #              req.create_jobs_for_env(env, [job.list], nbs ? ('execution.restriction'+ nbs) : nil)
              req.create_jobs_for_env(env, [job.list], job.run_options)
              # INFO  11-11-21 18:19:49 Commandline -o option "-roccTest_2" specified as: nil, overriding: nil
              Rails.logger.info "[DEBUG] Created job/request #{req.jobs.first.id}/#{req.id}"
            end
          end
        end
      end
    end
    jb = nil
    mlist = mach.env_list.gsub(/,/,"','")
    Job.transaction do
      sql = "stop_erequest_id is null and machine_id is null and environment_name in ('#{mlist}')"
      jobs = Job.where(sql).reverse_order.lock("LOCK IN SHARE MODE")
      #      Rails.logger.warn "[DEBUG] JIDS #{jobs.collect { |j| j.id  }.inspect}"
      mach.env_list.split(',').each do |e|
        jb = jobs.find { |j| j.environment_name == e }
        break if jb
      end
      if jb  # See if machine repo has needed version for job,
        # if not, ignore the request and restart the machine instead
        repo = jb.erequest.repo_version
        if repo and mach.repo_version and mach.repo_version != '' and
            ((repo.size < 7 and repo.to_i > mach.repo_version.to_i)  or # SVN Case
              (repo.size >= 7 and repo != mach.repo_version) # Git case, since it has more characters
             )
          restart_agent = true
          mach.agent_info = 'Restart due to repository version change'
#        elsif mach.job and mach.job.browser == 'firefox'
#          prev_job = Job.where("list_name = '#{jb.list_name}' AND is_results_final = 1 AND environment_name = '#{jb.environment_name}'").first # scoped desc
#          restart_agent = (prev_job.nil? or prev_job.browser != 'firefox') ? true : false
#          mach.agent_info = 'Restart due to browser change'
        end
        if restart_agent
          mach.user = jb.erequest.user
          mach.start(repo)
        else
          jb.repo_version = mach.repo_version
          unless jb.repo_version.to_s == repo.to_s
            msg= "ERROR: Unexpected job/machine.repo_version [#{jb.repo_version}] differs from requested version [#{repo}]"
            jb.results_error = jb.results_error ? (jb.results_error + msg) : msg
            Rails.logger.warn jb.results_error
          end
          jb.logfile = mach.logfile
          jb.machine = mach
          mach.job = jb
          mach.save
          jb.repo_version = mach.repo_version
          jb.started_at = Time.now
          jb.save
          Rails.logger.warn "Selected job #{jb.id} for #{mach.nickname}"
        end
      end
    end
    jb
  end

  def new_bug_cnt
    new_bugs.size
  end

  def new_bugs
    return @new_bugs if @new_bugs
    bugs = []
    for tst_idx, jobtest, different in self.bugs_failed  do
      bugs.push(tst_idx) if different
    end
    return @new_bugs = bugs
  end

  def Job.unfinished_for_env(env)
    return Job.find_all_by_environment_name_and_stop_erequest_id_and_is_results_final(env.name, nil, 0)
  end

  # Seems for debug only, remove this
  #  def Job.timeProc(name)
  #    $timeProc = {} unless $timeProc
  #    $timeProc[name] = 0 unless $timeProc[name]
  #    t1 = Time.now.to_f
  #    yield
  #    t2 = Time.now
  #    $timeProc[name] += t2.to_f - t1
  #    puts "[DEBUG][#{t2.strftime(DF)}] #{name} #{$timeProc[name]}"
  #  end
  def Job.unfinished_for_erequest_id(req_id)
    return Job.find_all_by_erequest_id_and_stop_erequest_id_and_finished_at_and_is_results_final(req_id, nil,nil,0)
  end

  # That have the lists included in the env
  def Job.latest_jobs_for_env(env)
    sql = "select jobs.* from jobs inner join
      (select max(j.id) as max_id
      FROM jobs j join lists l on j.list_name = l.name
      inner join erequests er on j.erequest_id = er.id
      inner join environments_lists el on el.list_id = l.id and er.environment_id = el.environment_id
      where j.environment_name = '#{env.name}' and j.machine_id is not null
      and j.total is not null
      and l.deleted_at is null and j.is_results_final = 1
      group by j.list_id)
      as ids on jobs.id = ids.max_id order by id desc;"
    #    Rails.logger.info "Executing sql: #{sql}"
    #     and l.deleted_at is null and j.stop_erequest_id is null
    return Job.find_by_sql(sql)
  end

  def jobtest_with_test(test)
    testid = test.instance_of?(Hash) ? test['id'] : test
    return @jobtest_with_testid_response if testid == @jobtest_with_testid_input
    @jobtest_with_testid_input = testid # Do some caching to avoid the third DB call
    # There are two calls already one for erequest one for job
    #    sql = "jobs.list_id = #{list_id} AND jobtests.testid = '#{testid}'" +
    sql = "jobs.list_id = #{list_id} AND jobtests.testid = '#{testid}' AND jobtests.job_id <= #{id}" +
      " AND jobtests.deleted_at is NULL"
    jt = Jobtest.joins(:job,:bug).readonly(false).where(sql).order('jobs.id DESC').first # apparently join implies readonly by default
    #    pp sql
    #    pp jt.id if jt
    # If bug is deleted after job is created ignore this jt
    if jt
      if jt.passed and jt.passed <= id
        jt = nil
      elsif jt.bug.deleted_at and created_at > jt.bug.deleted_at
        jt = nil

        #elsif test['status'] == 0
        #  bv = build_version
        #  this_version = bv[bv['execution']]
        #  jtbv = jt.job.build_version
        #  bug_version = jtbv[jtbv['execution']]
        #  jt = nil if this_version and bug_version and this_version > bug_version
      end
    end
    @jobtest_with_testid_response = jt
    return jt
  end

  def delete_jobtest_with_testid(id)
    jobtest = jobtest_with_test(id)
    return nil unless jobtest
    jobtest.delete
    return true
  end
  # id
  # return nil if both passes or skip
  # at 0: old jobtest or nil if new
  # at 1: different
  def bug_different(tst)
    tst_status = tst['status']
    return [nil,nil] if tst_status == 2
    testid = tst['id']
    tst_errors = tst['errors']
    jobtest = jobtest_with_test(tst)
    if tst_status == 0
      return [nil,nil] if jobtest.nil? # both passes
      unless jobtest.job  # Should never happen
        Rails.logger.info "ERROR: Encountered jobtest #{jobtest.id} without a job"
        return [jobtest,true]
      end
      # Handle bug passing in a new build. Maybe should be handled in jobtest_with_testid
      #      bv = self.build_version
      #      this_version = bv[bv['execution']]
      #      bug_version = jobtest.job.build_version[jobtest.job.build_version['execution']]
      #      if this_version and bug_version
      #        if this_version > bug_version
      #          return [jobtest,true]
      #        else
      #          return [nil,nil]
      #        end
      #      else # Used to fail, but now pass
      if jobtest.bug.deleted_at
        return [nil,nil] # Deleted bugs now passing are OK
      else
        return [jobtest,true] # returned as different unless bug was deleted
      end
      #      end
    end
    return [jobtest,nil] unless tst_status == 1 # tst is not finished yet
    ## current job failed
    return [nil,true] if jobtest.nil? # new bug
    # both failed
    return [jobtest,nil] unless jobtest.job
    bug_tst = jobtest.job.tests.find {|t| testid == t['id'] }
    if bug_tst
      bug_tst_errors = bug_tst['errors']
      differ = false
      tst_errors.each_with_index do |err,err_num|
        if bug_tst_errors[err_num].nil? or # Different number of errors
          err[0] != bug_tst_errors[err_num][0] # Exception class
          differ = true
        elsif err[1].gsub(/#<[^>]*>|\d*/,'') != bug_tst_errors[err_num][1].gsub(/#<[^>]*>|\d*/,'')
          differ = true
        elsif err[2]
          err[2].each_index do |exc_line_num|
            err_line = err[2][exc_line_num]
            if bug_tst_errors.nil? or bug_tst_errors[err_num].nil? or
                bug_tst_errors[err_num][2].nil?  or bug_tst_errors[err_num][2][exc_line_num].nil?
              # Take out the line numbers which might change, also the root part of the path to oats
              differ = true
              break
            end
            bug_line =   bug_tst_errors[err_num][2][exc_line_num]
            ## Take out the line numbers which might change, also the root part of the path to oats
            if  err_line.sub(/.*?\/oats\//,'').sub(/\.rb:\d*(:|\z)/,'') != bug_line.sub(/.*?\/oats\//,'').sub(/\.rb:\d*(:|\z)/,'')
              differ = true
              break
            end
          end
        elsif ! bug_tst_errors[err_num][2].nil?
          differ = true
        end
        break if differ
      end
      #      return [jobtest,true] #if differ # debug
      return [jobtest,true] if differ # different failure
      return [jobtest,nil] # same failure as old bug
    else
      return [jobtest,nil] # Should really never happen, unless lists changed
    end
  end

  # Return tst index, bugs array, and difference in an array
  def bugs_failed
    return @bug_differences if @bug_differences
    fail = []
    if self.tests and self.tests.instance_of? Array
      self.tests.each_with_index do |tst,idx|
        #        unless tst.instance_of?(TestCase)
        #          msg = "Expected a test case in #{self.list_name} but got:"
        #          Rails.logger.error "#{msg} #{tst.inspect}"
        #          puts msg; pp tst
        #          msg = "... in job:"
        #          Rails.logger.error "#{msg} #{self.inspect}"
        #          puts msg; pp self
        #          msg = "You need to delete this Job manually from DB"
        #          Rails.logger.error msg
        #          puts msg
        #          next
        #        end
        jobtest, differ = self.bug_different(tst)
        fail << [idx,jobtest,differ] if differ or tst['status'] == 1
      end
    end
    @bug_differences = fail
  end


end
