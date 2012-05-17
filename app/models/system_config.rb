class SystemConfig < ActiveRecord::Base
  before_save { |u|  u.value = nil if u.value == '' }

  def self.repo_url(repo)
    ENV['OATS_TESTS_GIT_REPOSITORY']+'/commit/'+repo if ENV['OATS_TESTS_GIT_REPOSITORY']
  end
end
