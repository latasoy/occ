class EnvironmentsController < ApplicationController
  before_filter :decode_id , :except => [:index, :all, :summary, :new, :create]
  before_filter :only => [ :stop, :destroy, :undelete, :create, :update] do |c|
    c.send(:authorize, "level" => 3) 
  end
  before_filter :ensure_domain, :only => :summary
  respond_to :html, :xml, :json

  # GET /environments
  # GET /environments.xml
  def index(environments = Environment.active)
    respond_with(@environments = environments)
  end

  # GET /environment/all
  def all
    index Environment.all
  end

  def summary
    respond_with(@environments = Environment.active)
  end

  # GET /environments/1
  # GET /environments/1.xml
  def show
    @environments = Environment.active # Why is this?
    respond_with(@environment)
  end

  def failed
    show
  end

  def new_failed
    show
  end

  # GET /environments/new
  # GET /environments/new.xml
  def new
    @environment = Environment.new
    @lists = List.active
  end

  # GET /environments/1/edit
  def edit
    @lists = List.all :conditions => {:deleted_at => nil}
  end

  # POST /environments
  # POST /environments.xml
  def create
    params[:environment][:name].strip! if params[:environment][:name]
    @environment = Environment.new(params[:environment])
    @lists = List.all
    respond_to do |format|
      if @environment.save
        Machine.reset_env_lists
        flash[:notice] = 'Environment was successfully created.'
        format.html { redirect_to environments_path }
        format.xml  { render :xml => @environment, :status => :created, :location => @environment }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @environment.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /environments/1
  # PUT /environments/1.xml
  def update
    old_env = Environment.find(params[:id])
    Machine.reset_env_lists unless old_env.agents == params[:environment][:agents] and
      old_env.name == params[:environment][:name]
    @lists = List.active
    want_delete = (params['delete'] == '1')
    if @environment.deleted_at.nil? == want_delete
      params[:environment]['deleted_at'] = params['delete'] ?  Time.now : nil
    end
    params[:environment][:list_ids]=[] unless params[:environment][:list_ids]
    params[:environment][:name].strip! if params[:environment][:name]
    params[:environment][:rerun] ||= nil
    respond_to do |format|
      if @environment.update_attributes(params[:environment])
        flash[:notice] = "Environment '#{@environment.name}' was successfully updated."
        format.html { redirect_to environments_path }
        #        format.html { redirect_to (@environment) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @environment.errors, :status => :unprocessable_entity }
      end
    end
  end

  def undelete
    @environment.update_attributes(:deleted_at => nil)
    Machine.reset_env_lists
    redirect_to :back
  end

  # DELETE /environments/1
  # DELETE /environments/1.xml
  def destroy
    @environment.update_attributes(:deleted_at => Time.now)
    Machine.reset_env_lists
    respond_to do |format|
      format.html { redirect_to(:back) }
      format.xml  { head :ok }
    end
  end

  # GET /environment/1/start
  def start
    unless authorize("level" => 3, 'role'=> 10)
      Rails.logger.info "Could not start due to lack of permissions: #{flash[:error]}."
      return
    end
    if params['build']
      req = @environment.start_build @current_user, params['build']
    else
      req = @environment.start @current_user
    end
    warn = @environment.message
    warn ||= req.message if req
    flash[:warning] = warn if warn
    if req
      respond_to do |format|
        format.html { redirect_to environment_path(@environment) }
      end
    else
      if request.env["HTTP_REFERER"]
        redirect_to :back
      else
        redirect_to environment_path(@environment)
      end
    end
  end

  # GET /environment/1/stop
  def stop
    req = @environment.stop(@current_user)
    warn = @environment.message
    warn ||= req.message if req
    flash[:warning] = warn if warn
    respond_to do |format|
      format.html { redirect_to environment_path(@environment) }
    end
  end

  private
  def decode_id
    id = params[:id].downcase
    unless id or id !~ /\A\w+\Z/
      err = "Unrecognized id [#id]"
    else
      if id =~ /\A\d+\Z/
        @environment = Environment.find(id)
      else
        @environment = Environment.find_by_name(id)
      end
    end
    err = "Can not locate environment with id [#{id}]" unless @environment
    if err
      flash[:notice] = err
      redirect_to environments_path
    end
  end

end
