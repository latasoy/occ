source 'http://rubygems.org'
gem 'rails' , '3.2.17'
gem 'mongrel', '>= 1.2.0.pre2'
#gem 'thin'
gem 'mysql2'
gem 'omniauth'
gem 'omniauth-openid' # For Yahoo and google/openid
gem 'omniauth-google-oauth2' if ENV['OATS_GOOGLE_KEY'] # If you want to use google-oauth2

# Include oats_agent gem unless a development version exists next to occ
gem 'oats_agent' unless File.directory? File.expand_path('../../oats_agent', __FILE__)
# gem 'sidekiq'
if RUBY_PLATFORM =~ /(mswin|mingw)/
  gem 'eventmachine',  '=0.12.10'
else
  gem 'eventmachine'
end
if RUBY_PLATFORM =~ /linux/ # Seems to be needed by Ubuntu-- For OCC or OATS?
  gem 'execjs'
  gem 'rake'
  gem 'therubyracer'
end

# Use ruby-debug for Ruby 1.8.7+,
# gem 'ruby-debug'
# 
# Use ruby-debug19 for Ruby 1.9.2+, need to follow this portion of
#  http://noteslog.com/post/netbeans-6-9-1-ruby-1-9-2-rails-3-0-0-debugging
# by editin the file (Ruby folder)/lib/ruby/gems/1.9.1/gems/ruby-debug-ide19-0.4.12/bin/rdebug-ide.rb as follows
# #  noteslog.com, 2010-09-17 -> !!!
# # 78 Debugger::PROG_SCRIPT = ARGV.shift
# script = ARGV.shift
# Debugger::PROG_SCRIPT = (script =~ /script([\\\/])rails/ ? Dir.pwd + $1 : '') + script
#gem 'ruby-debug19', :require => 'ruby-debug'

# Gems used only for assets and not required in production environments by default.
group :assets do
  gem 'sass-rails'
  gem 'coffee-rails'
  gem 'uglifier'
end

gem 'jquery-rails'

group :test do
  # Pretty printed test output
  gem 'turn', :require => false
end
