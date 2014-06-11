class JobsController < ApplicationController
  # GET /jobs
  # GET /jobs.xml
  respond_to :html, :xml, :json
  before_filter :only => [:remove_bug] do |c|
    c.send(:authorize, "level" => 3)
  end

  # POST /jobs
  # POST /jobs.json
  def create
    if params[:jobid]
      @job = Job.find_by_runid(params[:jobid])
      unless @job
        env = Environment.find_by_name(params[:environment_name])
        req = env.erequests.create!(:user => User.first, :command => 'start')
        @job = req.jobs.create
        @job.environment_name = env.name
      end
      list = List.find_by_name(params[:list_name])
      @job.start_time = params[:start_time]
      @job.end_time = params[:end_time]
      @job.runid = params[:jobid]
      @job.is_results_final = true
      @job.list = list
      @job.list_name = list.name
      if params[:machine]
        @job.machine = Machine.find_by_nickname(params[:machine])
      else
        @job.machine = Machine.first
      end
      @job.process_oats_results_info(params)
      @job.process_oats_results_info(params)
    end
    respond_with(@job)
  end

  def index
    respond_with(@jobs = Job.all)
  end

  # GET /jobs/nxt?...
  def nxt
    @job = Job.nxt(params)
    if @job
      full_nam = @job.list.name
      extension = full_nam.sub(/.*\./, '')
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
    Jobtest.remove params[:id], params[:testid]
    redirect_to :back
  end

  def pass
    jt = Jobtest.find(params[:jobtest_id])
    jt.pass(params[:id])
    redirect_to :back
  end

end