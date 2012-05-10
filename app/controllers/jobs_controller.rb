class JobsController < ApplicationController
  # GET /jobs
  # GET /jobs.xml
  respond_to :html, :xml, :json
  before_filter :only => [:remove_bug] do |c|
    c.send(:authorize, "level" => 3)
  end

  def index
    respond_with(@jobs = Job.all)
  end

  # GET /jobs/nxt?...
  def nxt
    @job = Job.nxt(params)
    if @job
      full_nam = @job.list.name
      extension = full_nam.sub(/.*\./,'')
      full_nam += '.yml' if extension == full_nam
    end
    render :json => @job ? {'jid' => @job.id, 'env' => @job.erequest.environment.file_name,
      'list' => full_nam, 'options' => @job.run_options, 'user' => @job.erequest.user.email} : {}
  end

  # GET /jobs/1
  # GET /jobs/1.xml
  def show
    begin
      @environments = Environment.active
      @job = Job.find(params[:id])
      @environment = @job.erequest.environment
    rescue Exceptions::MachineExceptions => exc
      flash[:notice] = exc.message
    end
    respond_with(@job)
  end

  def remove_bug
    # @bug = Bug.find params[:id]
    Jobtest.remove params[:id] , params[:testid]
    redirect_to :back
  end

  def pass
    jt = Jobtest.find(params[:jobtest_id])
    jt.pass(params[:id])
    redirect_to :back
  end

end