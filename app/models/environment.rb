class Environment < ActiveRecord::Base
  has_many :erequests  # Start and stop erequest
  has_and_belongs_to_many :lists
  validates :name, :presence => true
  validates_uniqueness_of :name, :case_sensitive => false
  attr_reader :message
  default_scope :order => 'name'
  scope :active, where(:deleted_at => nil)
  attr_accessor :unfinished_jobs
  validate :file_exists

  def file_exists
    errors.add('file',"Can not locate #{file_name}") unless TestData.locate(file_name + '.yml')
  end

  def file_name
    fname = (file and file != '') ? file : name
    fname.sub(/.*\//, '').sub(/(.*)\..*/, '\1')
  end

  # Return nil if unchanged
  # Otherwise sets @unfinished_jobs and returns true
  def changed?
    if self.started_at or self.sum_row.nil?
      @unfinished_jobs = Job.unfinished_for_env(self)
      return true
    else
      @unfinished_jobs = nil
      return false
    end
  end

  def start_build(user,name)
    lists = Job.latest_jobs_for_env(self).collect do |job|
      if job.machine
        job.list if job.build_version['execution'] == name
      end
    end
    self.start user,lists.compact
  end

  def start(user,env_list = nil, extra_run_options = nil)
    unless env_list
      skip_if_active = true # Called from environment start, at the top level
      env_list = self.lists.active
    end
    if env_list.empty?
      @message = "Environment #{self.name} has no lists."
      return nil
    end
    transaction do
      self.lock! "LOCK IN SHARE MODE"
      if skip_if_active and self.started_at
        @message = "Environment '#{self.name}' is already active"
        logger.info @message
        return nil
      else
        self.started_at = Time.now
        req = self.erequests.create(:command => 'start', :user => user )
        unless req['id']
          @message = req.message || req.errors.messages
          return nil
        end
        ro = run_options
        if extra_run_options
          if ro
            ro += ',' + extra_run_options
          else
            ro = extra_run_options
          end
        end
        req.create_jobs_for_env(self, env_list, ro)
        req.start_machines
        self.save
        # Somehow need to refresh the object, otherwise message doesn't showup
        return Erequest.find(req.id)
      end
    end
  end

  # Stop any outstanding jobs for an environment using a stop request
  def stop(user, jobs = nil)
    #    sql = "select job.* from jobs as job inner join erequests as erequest on job.erequest_id = erequest.id"
    #    sql += " where erequest.environment_id = #{env.id} and job.stop_erequest_id IS NULL and job.finished_at IS null;"
    #    sql = "select job.* from jobs where environment_name = '#{env.name}'"
    #    sql += " and stop_erequest_id IS NULL and job.finished_at IS null;"
    jobs ||= Job.find_all_by_environment_name_and_stop_erequest_id_and_finished_at(name, nil,nil)
    if jobs.empty?
      @message = "Environment '#{self.name}' has no active jobs."
      return nil
    end
    req = self.erequests.build(:command => 'stop', :user => user )
    req.stop_jobs(jobs) unless jobs.empty? # Job.find_by_sql(sql)
    req.save
    return Erequest.find(req.id)
  end

  def last_start_erequest # find first, since they are reverse ordered
    self.erequests.find :first, :conditions => ["command = 'start'"]
  end

end