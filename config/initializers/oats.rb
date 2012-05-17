require 'oats/rclient' # Called via machine to communicate with rserver
require 'oats/user_api' #  Interface methods to user methods implemented in other modules
require 'oats/test_data' # Needed to unmarshal oats_info object in rclient
require 'oats/report' # Used in views/jobs/_jobs_table.html.erb ot get failed file nane
$log = Rails.logger

unless ENV['HOSTNAME']
  if RUBY_PLATFORM =~ /(mswin|mingw)/
    ENV['HOSTNAME'] = ENV['COMPUTERNAME']
  else
    ENV['HOSTNAME'] = `hostname`.chomp
  end
end

# Configuration parameters controlling OATS/OCC/Agent behavior
# Most of these can be set in here or from the environment

# NOTE: In addtion to the below, a secret is required to generate an integrity 
# hash for cookie session data.  Define ENV['COOKIE_SECRET'] or 
# Use config.secret_token = "some secret phrase of at least 30 characters in
#   .../occ/config/initializers/secret_token.rb
# You can generate it by 'cd occ; rake secret'

dir_tests = ENV['OATS_TESTS']
unless File.directory?(dir_tests)
  raise "Can not locate OATS_TESTS: #{dir_tests}" unless ENV['OATS_TESTS_GIT_REPOSITORY']
  `git clone #{ENV['OATS_TESTS_GIT_REPOSITORY']} #{dir_tests}`
end

server_host = ENV['OATS_OCC_HOST'] || ENV['HOSTNAME']
Occ::Application.config.occ = {
  
  # For agent to contact occ. Also what occ host sees itself as, via ENV['HOSTNAME'].downcase
  'dir_tests'         => dir_tests,
  
  # For agent to contact occ. Also what occ host sees itself as, via ENV['HOSTNAME'].downcase
  'server_host'       => server_host ,
  
  # OCC server port for OCC to request agent to contact
  'server_port'       => ENV['OATS_OCC_PORT'] || 3000,
  
  # Define if using GIT for test repository
  'git_repository'       => ENV['OATS_TESTS_GIT_REPOSITORY'] ,
    
  # Define if using SVN for test repository
  'svn_repository'       => ENV['OATS_TESTS_SVN_REPOSITORY'] ,
  
  # Bugs will be displayed as a link using this 
  'bug_url_prefix'       => 'https://redmine.gr-apps.com/issues/' ,
  
  # Timeout for agent to respond, should respond quickly, unless dead
  'timeout_waiting_for_agent' => 10,
  
  # Corresponds to the oats build versions
  'build_versions' => ['web'],
  
  # OCC delegates to this for serving static files. By default each agent machine serves its own files.
  # Set this if you want a single webserver serving results of eachagent machine names via an alias.
  # Requires each agent results to be file-shared with the webserver
  'results_webserver' => nil,
  
  # If set, bypass login request, and use this id to login all users for development w/o network access
  'login_user_service_id'    => nil, # 2
  
  # Make sure users come in via standard fully-qualified domain, needed for 
  # Google_oauth2 (see below).   Define this only for prod environment
  'occ_server_host_qualified' => ENV['OCC_SERVER_HOST_QUALIFIED'] ,
  # Client ID and Secret for Auth2
  'google_key' => ENV['OATS_GOOGLE_KEY'] ,
  'google_secret' => ENV['OATS_GOOGLE_SECRET'] ,
}

# To use google oath2, go to https://code.google.com/apis and create a project
# and a Client ID for web application. After you are done, Client ID settings
# should look something like this
# 
# Client ID:      879436149380.apps.googleusercontent.com
# Email address:	879436149380@developer.gserviceaccount.com
# Client secret:	hwWyMBJ6rx1aUP0DbSjHlovT
# Redirect URIs:	http://localhost:3000/auth/google_oauth2/callback
#                 http://occhost.my.com:3000/auth/google_oauth2/callback
# JavaScript origins:	http://localhost
#                     http://my.com



