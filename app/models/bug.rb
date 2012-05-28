class Bug < ActiveRecord::Base
  has_many :jobtests
  validates :key, :presence => true
  validates_uniqueness_of :key, :case_sensitive => false
  before_validation :downcase_key
  scope :active, where(:deleted_at => nil)

  # Commented for now since with new Jira even read-only requires login.
  # Uncomment once a safe read-only user/password can be used in configs.
  #  validates_each :key do |model, attr, value|
  #    found = false
  #    begin
  #      #      url = "/browse/#{value}"
  #      #      resp = Net::HTTP.new(JiraHost, 443).get(url, nil )
  #      http = Net::HTTP.new(JiraHost,443)
  #      req = Net::HTTP::Get.new(Bug.url(value))
  #      http.use_ssl = true
  #      #      req.basic_auth "levent.atasoy", ''
  #      resp = http.request(req)
  #      found = ! resp.body.index('does not exist') if resp.code == '200'
  #    rescue
  #      Rails.logger.warn $!.to_s
  #      Rails.logger.warn "Occurred after issuing get request to #{Bug.url(value)}"
  #    end
  #    model.errors.add(attr, ' does not correspond to an existing Jira ticket') unless found
  #  end

  def url
    return nil unless key and Occ::Application.config.occ['bug_url_prefix']
    Occ::Application.config.occ['bug_url_prefix'] + key
  end

  protected
  def downcase_key
    self.key = self.key.downcase
  end

end
