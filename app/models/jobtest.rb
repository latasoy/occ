class Jobtest < ActiveRecord::Base
  belongs_to :job
  belongs_to :bug
  default_scope :order => 'job_id desc', :limit => 500
  scope :active, where(:deleted_at => nil)
  scope :failing, where(:deleted_at => nil,:passed => nil)
  validates :job, :presence => true
  #  validates :bug, :presence => true # Having this causes error.
  #  Since they have to be created simultaneously?
  #  In any case not needed since only created via saving the bug, and auto-skipped if that fails
  validates :testid, :presence => true
  #  default_scope :order => 'id desc'
  validates :testid, :uniqueness => { :scope => [:job_id, :bug_id, :deleted_at] }, :on => :create
  #  validate :unique_testid
  #  def unique_testid
  #    return unless bug and testid and job
  #    existing = Jobtest.failing.find_by_testid_and_bug_id_and_job_id(testid,bug.id,job.id)
  #    errors.add('Testid'," #{testid} is already associated with bug #{bug.id} for job #{job.id}") if existing
  #  end

  def Jobtest.remove(jobid,testid)
    job = Job.find jobid
    return job.delete_jobtest_with_testid(testid)
  end

  def delete
    now = Time.now
    self.update_attributes(:deleted_at => now)
    self.save!
    if bug.jobtests.failing.empty?
      bug.deleted_at = now
      bug.save
    end
  end

  def pass(job_id)
    self.passed = job_id
    self.save
    if bug.jobtests.failing.empty?
      bug.deleted_at = Time.now
      bug.save
    end
  end
end
