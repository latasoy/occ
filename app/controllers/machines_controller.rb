class MachinesController < ApplicationController
  before_filter :retrieve , :except => [:index, :all, :refresh]
  before_filter :except => [:index, :all, :refresh, :status] do
    |c| c.send(:authorize, "level" => 3)
  end
  respond_to :html, :xml, :json

  # GET /machines
  # GET /machines.xml
  def index
    respond_with @machines = Machine.active
  end

  def all
    respond_with @machines = Machine.all
  end

  #  GET /machines/refresh
  # Does a status on each active machine, to be used as heartbeat by cron
  def refresh
    messages = Machine.refresh(current_user).compact
    flash[:warning] = messages.join(" ") unless messages.empty?
    redirect_to machines_path
  end

  def undelete
    @machine.undelete
    Machine.reset_env_lists
    redirect_to all_machines_path
  end

  def start
    @machine.agent_info = 'Restart requested by user'
    @machine.start
    redirect_to machines_path
  end

  def shutdown
    @machine.agent_info = 'Shutdown requested by user'
    @machine.shutdown
    redirect_to machines_path
  end

  def status
    # For some reason other calls ends up here at the end
    return unless action_name == 'status'

    @machine.status
    flash[:warning] = @machine.message if @machine.message
    #    @machines = Machine.active
    index
    #redirect_to machines_path  # Somehow causes multiple redirects. had to duplicate view
  end
  #
  # DELETE /machines/1
  # DELETE /machines/1.xml
  def destroy
    # @machine.destroy
    @machine.update_attributes(:deleted_at => Time.now)
    Machine.reset_env_lists
    respond_to do |format|
      format.html { redirect_to(machines_url) }
      format.xml  { head :ok }
    end
  end

  def retrieve
    id = params[:id]
    unless id or id !~ /\A\w+\Z/
      err = "Unrecognized id [#id]"
    else
      if id =~ /\A\d+\Z/
        @machine = Machine.find(id)
      else
        @machine = Machine.find_by_nickname(id.downcase)
      end
      if @machine
        @machine.user = current_user
      else
        err = "Can not locate machine with id [#{id}]"
      end
    end
    if err
      flash[:notice] = err
      redirect_to machines_path
    end
  end
end