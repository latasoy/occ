class Service < ActiveRecord::Base
  belongs_to :user
  attr_accessible :provider, :uid, :name, :email, :first_name, :last_name, :app_server,
    :image, :url, :gender, :locale, :phone, :location, :description, :nickname
end
