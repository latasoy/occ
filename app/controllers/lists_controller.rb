class ListsController < ApplicationController
  respond_to :html, :xml, :json
  before_filter :only => [:edit, :create, :destroy, :undelete, :run, :update] do
    |c| c.send(:authorize, "level" => 3)
  end

  # GET /lists
  def index(lists = nil)
    respond_with( @lists = lists || List.active )
  end

  # GET /lists/all
  def all
    respond_with(@lists = List.all)
  end

  # GET /lists/tests
  def tests
    respond_with(@lists = List.active)
  end


  # GET /lists/filename.ext
  # GET /lists/1
  # GET /lists/1.xml
  def show
    if params[:id] =~ /^\d+/
      @list = List.find(params[:id])
      @list.test_count  # See if it generates errors
      flash[:warning] = @list.errors.to_s unless @list.errors.empty?
      respond_with(@lists = List.active)
    else
      @list = params[:id] + '.' + params[:format]
      render :template => "lists/show.html" , :layout => "layouts/lists.html" #, :html => @list
    end
  end


  # GET /lists/new
  # GET /lists/new.xml
  def new
    respond_with(@list = List.new)
  end

  # GET /lists/1/edit
  def edit
    @list = List.find(params[:id])
  end

  # GET /lists/1/jobs
  def jobs
    @list = List.find(params[:id])
    @jobs = Job.find_all_by_list_id(params[:id])
    @jobs.reject! {|job| job.machine.nil?}
    respond_with(@jobs)
  end

  # POST /lists
  # POST /lists.xml
  def create
    if params[:list][:name]
      params[:list][:name].strip!
      params[:list]['name'].sub!(/.yml\z/i,'')
    end
    @list = List.new(params[:list])
    #    @list.environments = Environment.all  # Don't add environments automatically
    respond_to do |format|
      if @list.save
        flash[:notice] = "List '#{@list.name}' was successfully created."
        format.html { redirect_to lists_url }
        format.xml  { render :xml => @list, :status => :created, :location => @list }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @list.errors, :status => :unprocessable_entity }
      end
    end
  end


  # POST /lists/run
  def run
    job_request = params[params[:commit] == 'Run' ? :job : :unfinished_job]
    jobs = Job.find(job_request) if job_request
    lists = List.find(params[:list]) if params[:list]
    lists ||= jobs.collect{|j| j.list} if jobs
    unless lists
      flash[:warning] = "Please select lists to #{ params[:commit]}!"
      redirect_to :back
      return
    end
    # Handle Run or Stop Job request
    environment = Environment.find(params[:environment][:id])
    if params[:environment][:id] == ''
      flash[:warning] = "Please select the applicable environment!"
      redirect_to :back
      return
    end
    if params[:commit] == 'Run'
      req = environment.start(@current_user, lists, params[:run_options])
    else
      req = environment.stop(@current_user, jobs)
    end
    msg = environment.message || req && req.message
    flash[:warning] = msg.to_s if msg
    if req and params[:commit] == 'Run'
      respond_to do |format|
        format.html {  redirect_to environment_path(environment) }
      end
    else
      redirect_to :back
    end
  end

  # PUT /lists/1
  # PUT /lists/1.xml
  def update
    if params[:list][:name]
      params[:list][:name].strip!
      params[:list]['name'].sub!(/.yml\z/i,'')
    end
    @list = List.find(params[:id])
    new_list = List.new(:name => params[:list][:name] )
    params[:list][:rerun] ||= nil
    respond_to do |format|
      if @list.update_attributes(params[:list])
        flash[:notice] = "List '#{@list.name}' was successfully updated."
        format.html { redirect_to lists_path }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => new_list.errors, :status => :unprocessable_entity }
      end
    end
  end

  def undelete
    @list = List.find(params[:id])
    @list.update_attributes(:deleted_at => nil)
    # @list.environments = Environment.active # Don't add to environments automaticall
    #    redirect_to lists_path
    redirect_to :back

  end

  # DELETE /lists/1
  # DELETE /lists/1.xml
  def destroy
    @list = List.find(params[:id])
    # @list.destroy
    @list.update_attributes(:deleted_at => Time.now)
    @list.environments.clear
    respond_to do |format|
      format.html { redirect_to :back }
      format.xml  { head :ok }
    end
  end
end
