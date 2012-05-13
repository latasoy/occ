# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  #  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  # Usage: <%= ifnil("no author"){ @post.author.name } %>
  #  def ifnil(value=nil)
  #    yield
  #  rescue NoMethodError
  #    raise unless $!.message =~ /:NilClass$/
  #    value
  #  end
  helper_method :current_user
  helper_method :current_service

  private
  
  def current_service
    service_id = $oats['execution']['occ']['login_user_service_id'] || session[:service_id]
    @current_service ||= Service.find_by_id(service_id) if service_id
  end

  def current_user
    @current_user = current_service.user if current_service
    @current_user ||= User.find_by_id(session[:user_id]) if session[:user_id]
    if @current_user and current_service
      @current_user.email = current_service.email
    elsif params.key?('user') and params.key?('password')
      @current_user = User.find_by_uname_and_password(params['user'],params['password'])
      @current_user.email = @current_user.uname if @current_user
      #      session[:user_id] = @current_user.id # will not get cleared
    end
    return @current_user
    #    elsif params['controller'] == 'machines' and params.key?('password') and params['password'] == @machine.password
    #      @current_user ||= User.find_by_level('1') # Use the first level one user
  end

  # Sets current_user and returns true if current_user is authorized
  def authorize(vars = nil)
    if current_user
      # Only users above this level are allowed into the application
      # Set this to 1 to temporarily disable OCC access to non-admin users.
      cutoff = SystemConfig.find_by_name(:user_level_cutoff)
      raise "SystemConfig for user_level_cutoff is not initialized" unless cutoff
      cutoff = cutoff.value
      if cutoff
        return true if current_user.level and  current_user.level <= cutoff.to_i
        flash[:error] = "OCC is currently undergoing maintenance. For questions, please contact occadmin@Your.org."
      else
        return true unless vars
        return true if current_user.level and current_user.level <= vars['level']
        return true if vars['role'] and vars['role'] = current_user.level
        action = action_name == 'destroy' ? 'delete' : action_name
        flash[:error] = "You need to have level #{vars['level']} permission to access #{action} page!"
      end
      unless request.env["HTTP_REFERER"]
        redirect_to :back
        return false
      end
    else
      flash[:error] = 'You need to sign in before accessing this page!'
    end
    #    session[:signin_services_redirect_path] = request.fullpath
    #    session[:parms] = params
    redirect_to signin_services_path
    return false
  end

  # Make sure users come in via standard fully-qualified domain, needed for Google_oauth2
  def ensure_domain
    server_full = ENV['OCC_SERVER_HOST_QUALIFIED'] # Define only for prod environment
    return unless server_full
    host = request.env['HTTP_HOST']
    app_domain = host.sub(/.*:/,server_full+':')
    if host != app_domain
      redirect_to "http://#{app_domain}"+request.fullpath #, :status => 301 # HTTP 301 is a "permanent" redirect
    end
  end

end
