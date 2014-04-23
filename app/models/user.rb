class User < ActiveRecord::Base
  has_many :services
  #  attr_accessible :level, :password, :uname
  has_many :erequests
  before_destroy { |u| u.services.destroy_all   }
  attr_accessor :email

  # Delegate requested attributes to those found in a Service, except for these
  EXCLUDED_ATTRIBUTES = ['id','updated_at', 'created_at']

  def respond_to?(sym, include_private = false)
    from_service?(sym) || super(sym)
  end

  def method_missing(sym, *args, &block)
    return from_service(sym) if from_service?(sym)
    super(sym, *args, &block)
  end

  def email
    @email ||= from_service(:email) # Unless was set by application_controller to System
  end

  def level
    attributes['level'] # @level doesn't work, probably active record uses method_missing
  end

  def name
    @name = from_service(:name) || uname
  end

  private
  def from_service?(sym)
    (Service.column_names - EXCLUDED_ATTRIBUTES).include?(sym.to_s)
  end
  def from_service(attr)
    service = self.services.all.find{|s| val = s.send(attr); val and val != '' }
    service ? service.send(attr) : nil
  end
end
