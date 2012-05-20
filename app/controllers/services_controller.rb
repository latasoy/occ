class ServicesController < ApplicationController
  before_filter :authorize, :except => [:create, :signin, :signup, :newaccount, :failure]
  before_filter :ensure_domain, :only => :signin
  protect_from_forgery :except => :create     # see https://github.com/intridea/omniauth/issues/203

  # GET all authentication services assigned to the current user
  def index
    @services = current_user.services.order('provider asc')
  end

  # POST to remove an authentication service
  def destroy
    # remove an authentication service linked to the current user
    @service = current_user.services.find(params[:id])

    if session[:service_id] == @service.id
      flash[:error] = 'You are currently signed in with this account!'
    else
      @service.destroy
    end
    redirect_to services_path
  end

  # POST from signup view
  def newaccount
    if params[:commit] == "Cancel"
      session[:authhash] = nil
      session.delete :authhash
      redirect_to root_url
    else  # create account
      # Google gives new uid/session for same email if app is called from different UIDs
      @newuser = User.new
      @newuser.level = 1 unless User.find_by_level(1) # Have at least one user as administrator
      @newuser.services.build(session[:authhash])
      if @newuser.save!
        # signin existing user
        # in the session his user id and the service id used for signing in is stored
        session[:user_id] = @newuser.id
        session[:service_id] = @newuser.services.first.id

        flash[:notice] = 'Your account has been created and you have been signed in!'
        redirect_to root_url
      else
        flash[:error] = 'This is embarrassing! There was an error while creating your account from which we were not able to recover.'
        redirect_to root_url
      end
    end
  end

  # Sign out current user
  def signout
    if current_user
      session[:user_id] = nil
      session[:service_id] = nil
      session.delete :user_id
      session.delete :service_id
      flash[:notice] = 'You have been signed out!'
    end
    redirect_to root_url
  end

  # callback: success
  # This handles signing in and adding an authentication service to existing accounts itself
  # It renders a separate view if there is a new user to create
  def create
    # get the service parameter from the Rails router
    params[:service] ? service_route = params[:service] : service_route = 'No service recognized (invalid callback)'

    # get the full hash from omniauth
    omniauth = request.env['omniauth.auth']

    # continue only if hash and parameter exist
    if omniauth and params[:service]

      # map the returned hashes to our variables first - the hashes differs for every service

      # create a new hash
      @authhash = { :app_server => self.env['SERVER_NAME'] }

      if service_route == 'google_oauth2'
        %w(provider uid).each { |a| @authhash[a.to_sym] = omniauth[a] || '' }
        %w(name email first_name last_name image nickname phone url location description).each { |a| @authhash[a.to_sym] = omniauth['info'][a] }
        %w(gender locale).each { |a| @authhash[a.to_sym] = omniauth['extra']['raw_info'][a]}
        @authhash[:url] = omniauth['extra']['raw_info'][:link] unless @authhash[:url]
      elsif ['google', 'yahoo', 'twitter', 'myopenid', 'open_id'].index(service_route)
        %w(provider uid).each { |a| @authhash[a.to_sym] = omniauth[a] || '' }
        %w(name email ).each { |a| @authhash[a.to_sym] = omniauth['info'][a] }
        #      elsif service_route == 'facebook'
        #        omniauth['extra']['user_hash']['email'] ? @authhash[:email] =  omniauth['extra']['user_hash']['email'] : @authhash[:email] = ''
        #        omniauth['extra']['user_hash']['name'] ? @authhash[:name] =  omniauth['extra']['user_hash']['name'] : @authhash[:name] = ''
        #        omniauth['extra']['user_hash']['id'] ?  @authhash[:uid] =  omniauth['extra']['user_hash']['id'].to_s : @authhash[:uid] = ''
        #        omniauth['provider'] ? @authhash[:provider] = omniauth['provider'] : @authhash[:provider] = ''
        #      elsif service_route == 'github'
        #        omniauth['info']['email'] ? @authhash[:email] =  omniauth['user_info']['email'] : @authhash[:email] = ''
        #        omniauth['info']['name'] ? @authhash[:name] =  omniauth['user_info']['name'] : @authhash[:name] = ''
        #        omniauth['extra']['user_hash']['id'] ? @authhash[:uid] =  omniauth['extra']['user_hash']['id'].to_s : @authhash[:uid] = ''
        #        omniauth['provider'] ? @authhash[:provider] =  omniauth['provider'] : @authhash[:provider] = ''
      else
        # debug to output the hash that has been returned when adding new services
        render :text => omniauth.to_yaml
        return
      end

      if @authhash[:uid] != '' and @authhash[:provider] != ''

        auth = Service.find_by_provider_and_uid(@authhash[:provider], @authhash[:uid])

        # if the user is currently signed in, he/she might want to add another account to signin
        if current_user
          if auth
            flash[:notice] = 'Your account at ' + @authhash[:provider].capitalize + ' is already connected with this site.'
            redirect_to services_path
          else
            current_user.services.create!(@authhash)
            flash[:notice] = 'Your ' + @authhash[:provider].capitalize + ' account has been added for signing in at this site.'
            redirect_to services_path
          end
        else
          if auth
            #            unless auth.app_server
            #              auth.app_server = self.env['SERVER_NAME']
            #              auth.save
            #            end
            # signin existing user
            # in the session his user id and the service id used for signing in is stored
            session[:user_id] = auth.user.id
            session[:service_id] = auth.id
            flash[:notice] = 'Signed in successfully via ' + @authhash[:provider].capitalize + '.'
            #            if session[:parms]
            #              url = url_for :controller => session[:parms][:controller], :action => session[:parms][:action],
            #                :id => session[:parms][:id]
            ##              url = url_for(session[:signin_services_redirect_path])
            #              session.delete :parms
            redirect_to root_url
            #            end
          else
            # this is a new user; show signup; @authhash is available to the view and stored in the sesssion for creation of a new user
            msg = nil
            [:email,:name, :last_name].find do |a|
              next unless a
              service = Service.where(a => @authhash[a]).first
              if service and @authhash[a]
                msg = "There is already a user #{a == :name ? '' : service.name+' '}with #{a.to_s} #{@authhash[a]} using #{service.provider} authentication. Please read the note below carefully and consider associating this authentication to your existing account."
                break
              end
            end
            flash[:notice] = msg if msg
            session[:authhash] = @authhash
            render signup_services_path
          end
        end
      else
        flash[:error] =  'Error while authenticating via ' + service_route + '/' + @authhash[:provider].capitalize + '. The service returned invalid data for the user id.'
        redirect_to signin_path
      end
    else
      flash[:error] = 'Error while authenticating via ' + service_route.capitalize + '. The service did not return valid data.'
      redirect_to signin_path
    end
  end

  # callback: failure
  def failure
    flash[:error] = 'There was an error at the remote authentication service. You have not been signed in.'
    redirect_to root_url
  end

end