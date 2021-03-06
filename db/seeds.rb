# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

# Dynamically modifiable system configs
SystemConfig.create([ 
    { :name => 'user_level_cutoff', :value => nil, 
      :description => 'Set to 1 to prevent lower level users from using the system.'},
    { :name => 'skip_users', :value => true,
      :description => 'Set it to anything to bypass user authentication.'}])

# Create a system user.
User.create([ {:level => 0, :uname => 'System', :password => 'SystemPass'}])
Service.create([ {:user_id => 1,}])

env_names = []
  Dir.glob(ENV['OATS_TESTS'] + '/environments/*.yml') do |filename|
    env_names << File.basename(filename,'.*')
  end
envs = []
env_names.each { |env_nam|
  env = {}
  env[:name] = env_nam
  env[:deleted_at] = Time.now
  Rails.logger.info("Created #{env}")
  envs << env
}
Environment.create(envs)
env_names = envs = nil # let garbage collect

lists = %w(
occTestlist.yml
)

list_arr = []
lists.each { |name|
  list = {}
  list[:name] = name
  # list[:deleted_at] = Time.now
  Rails.logger.info("Created #{list}")
  list_arr << list
}
List.create(list_arr)
lists = list_arr = nil # let garbage collect
