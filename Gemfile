source 'http://rubygems.org'
gem 'rails' , '3.2.1'
gem 'mongrel', '>= 1.2.0.pre2'

# On ubuntu mysql2 gem needs 'libmysqlclient-dev' package to be installed.
# On Mac, Make sure the env where NB started contains the DYLD path below.
# If getting uninitialized conts errors, start from NB fro shell where this defined.
# Better yet, for GUI, add this to ~/.netbeans/vers/etc/netbeans.config
#export DYLD_LIBRARY_PATH="/usr/local/mysql/lib:$DYLD_LIBRARY_PATH"
#sudo env ARCHFLAGS="-arch x86_64" /usr/bin/gem install --no-rdoc --no-ri mysql -- --with-mysql-config=/usr/local/mysql/bin/mysql_config
gem 'mysql2'

gem 'omniauth'
gem 'omniauth-openid' # For Yahoo, also google/openid
gem 'omniauth-google-oauth2'  # google-auth.gem is no good. It asks for contacts.
#gem 'omniauth-facebook'
#gem 'omniauth-twitter'
#gem 'omniauth-github'

gem "log4r"
gem 'eventmachine'

if ENV['OS'] == 'Linux' # Seems to be needed by Ubuntu-- For OCC or OATS?
  gem 'execjs'
  gem 'therubyracer'
end

# Bundle edge Rails instead:
#gem 'rails', :git => 'git://github.com/rails/rails.git'


# Use ruby-debug for Ruby 1.8.7+,
# gem 'ruby-debug'
# Use ruby-debug19 for Ruby 1.9.2+, need to follow this portion of
#  http://noteslog.com/post/netbeans-6-9-1-ruby-1-9-2-rails-3-0-0-debugging
# by editin the file (Ruby folder)/lib/ruby/gems/1.9.1/gems/ruby-debug-ide19-0.4.12/bin/rdebug-ide.rb as follows
# #  noteslog.com, 2010-09-17 -> !!!
# # 78 Debugger::PROG_SCRIPT = ARGV.shift
# script = ARGV.shift
# Debugger::PROG_SCRIPT = (script =~ /script([\\\/])rails/ ? Dir.pwd + $1 : '') + script
#gem 'ruby-debug19', :require => 'ruby-debug'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails'
  gem 'coffee-rails'
  gem 'uglifier'
end

gem 'jquery-rails'

# Use unicorn as the web server # does it work on LINUX?
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

group :test do
  # Pretty printed test output
  gem 'turn', :require => false
end
