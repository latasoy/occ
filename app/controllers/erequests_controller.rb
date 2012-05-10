class ErequestsController < ApplicationController
  # GET /erequests
  # GET /erequests.xml
  before_filter :only => [:stop] do
    |c| c.send(:authorize, "level" => 3)
  end

  respond_to :html, :xml, :json

  # GET /erequest/1/stop
  def stop
    begin
      start_erequest = Erequest.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:warning] = "There are no earlier start erequest with ID: #{params[:id]}"
      redirect_to requests_path
    end
    begin
      start_erequest.stop
    rescue Exceptions::MachineExceptions => exc
      flash[:warning] = exc.message
    end
    redirect_to erequest_path(start_erequest)
  end

  def index
    respond_with( @erequests = Erequest.find_all_by_command('start') )
  end

  # GET /erequests/1
  # GET /erequests/1.xml
  def show
    @environments = Environment.active
    @erequest = Erequest.find(params[:id])
    @environment = @erequest.environment
    respond_with(@erequest )
  end

  def failed
    show
  end
  def new_failed
    show
  end

  # DELETE /erequests/1
  # DELETE /erequests/1.xml
  #  def destroy
  #    @erequest = Erequest.find(params[:id])
  #    @erequest.destroy
  #
  #    respond_to do |format|
  #      format.html { redirect_to(erequests_url) }
  #      format.xml  { head :ok }
  #    end
  #  end
end
