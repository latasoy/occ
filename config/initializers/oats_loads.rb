require 'oats/rclient' # Called via machine to communicate with rserver
require 'oats/oats_data' # Called below
require 'oats/roptions' # Called below
require 'oats/oats' #  Interface methods to user methods implemented in other modules
require 'oats/test_data' # Needed to unmarshal oats_info object in rclient
require 'oats/report' # Used in views/jobs/_jobs_table.html.erb ot get failed file nane

#require 'jruby-openssl'
unless ENV['HOSTNAME']
  if ENV['OS'] == 'Windows_NT'
    ENV['HOSTNAME'] = ENV['COMPUTERNAME']
  else
    ENV['HOSTNAME'] = `hostname`.chomp
  end
end

$log = Rails.logger
$oats = Oats::OatsData.load #(ini_file)
Oats::Roptions.override #(options)

#ObjectSpace.each_object(Mongrel::HttpServer) do |i|
#  OCC::mongrel_port = i.port
#  raise "Port could not be introspected!" unless OCC::mongrel_port and OCC::mongrel_port.to_i > 0
#end
#logger 'MONGREL PORT is: ' + Mongrel::HttpServer.port

