require 'oats/rclient' # Called via machine to communicate with rserver
require 'oats/oats' #  Interface methods to user methods implemented in other modules
require 'oats/test_data' # Needed to unmarshal oats_info object in rclient
require 'oats/report' # Used in views/jobs/_jobs_table.html.erb ot get failed file nane

unless ENV['HOSTNAME']
  if RUBY_PLATFORM =~ /mswin32/
    ENV['HOSTNAME'] = ENV['COMPUTERNAME']
  else
    ENV['HOSTNAME'] = `hostname`.chomp
  end
end

# Configuration parameters controlling OATS/OCC/Agent behavior
Occ::Application.config.occ = {
  # For agent to contact occ. Also what occ host sees itself as, via ENV['HOSTNAME'].downcase
  'dir_tests'         => ENV['OATS_TESTS'],
  # For agent to contact occ. Also what occ host sees itself as, via ENV['HOSTNAME'].downcase
  'server_host'       => ENV['OATS_OCC_HOST'] || ENV['HOSTNAME'] ,
  # OCC server port for OCC to request agent to contact
  'server_port'       => ENV['OATS_OCC_PORT'] || 3000,
  # Timeout for agent to respond, should respond quickly, unless dead
  'timeout_waiting_for_agent' => 10,
  # Corresponds to the oats build versions
  'build_versions' => ['web'],
  # OCC to redirect for serving static files. Default is each agent machine.
  'results_webserver' => ENV['HOSTNAME'],
  # If set, bypass login request, and use this id to login all users for development w/o network access
  'login_user_service_id'    => nil # 2
}
$log = Rails.logger