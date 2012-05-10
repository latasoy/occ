class BugsController < ApplicationController
  before_filter :except => [:show,:all,:index] do
    |c| c.send(:authorize, "level" => 3)
  end

  respond_to :html, :xml, :json

  # GET /bugs
  # GET /bugs.xml
  def index
    respond_with(@bugs = Bug.active)
  end

  # GET /bugs/1
  # GET /bugs/1.xml
  def show
    respond_with(@bug = Bug.find(params[:id]) )
  end

  # GET /bugs/new
  def new
    @bug = Bug.new
    @jobtest = Jobtest.new(:job_id => params[:job], :testid => params[:testid])
    respond_with(@bug)
  end

  # POST /bugs
  # POST /bugs.xml
  def create
    testid = params[:jobtest][:testid]
    jobid = params[:jobtest][:job_id]
    #    job = Job.find jobid
    bug = Bug.find_by_key params[:bug][:key]
    if bug
      if bug.deleted_at
        msg = "Undeleted old existing bug #{params[:bug][:key]} and associated it to job #{jobid}, test #{testid}."
        bug.deleted_at = nil
      else
        msg = "Associated existing bug #{params[:bug][:key]} to job #{jobid}, test #{testid}."
      end
    else
      msg = "Created a new bug and associated to job #{jobid}, test #{testid}."
      bug = Bug.new(params[:bug])
    end
    @jobtest = bug.jobtests.build(params[:jobtest])
    @bug = bug
    respond_to do |format|
      if bug.save
        flash[:notice] = msg
        format.html { redirect_to(bug) }
        format.xml  { render :xml => bug, :status => :created, :location => bug }
      else
        jte = @jobtest.errors
        unless jte.empty?
          @bug.errors.clear
          jte.keys.each { |k| jte[k].each {|m| @bug.errors.add(k,m) } }
        end
        format.html { render :action => "new" }
        format.xml  { render :xml => bug.errors, :status => :unprocessable_entity }
      end
    end
  end

  # GET /bugs/1/edit
  def edit
    @bug = Bug.find params[:id]
  end


  # PUT /bugs/1
  # PUT /bugs/1.xml
  def update
    @bug = Bug.find(params[:id])
    @bug.jobtests.each{ |jt| jt.valid? }

    respond_to do |format|
      if @bug.update_attributes(params[:bug])
        flash[:notice] = 'Bug was successfully updated.'
        format.html { redirect_to(@bug) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @bug.errors, :status => :unprocessable_entity }
      end
    end
  end

  def all
    @bugs = Bug.all
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @bugs }
    end
  end

  # DELETE /bugs/1
  # DELETE /bugs/1.xml
  def destroy
    @bug = Bug.find(params[:id])
    #    @bug.destroy
    @bug.update_attributes(:deleted_at => Time.now) unless @bug.deleted_at
    respond_to do |format|
      format.html {redirect_to :back  }
      format.xml  { head :ok }
    end
  end

  def undelete
    @bug = Bug.find(params[:id])
    @bug.update_attributes(:deleted_at => nil)
    redirect_to :back
  end
end
