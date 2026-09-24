source 'https://rubygems.org'

gemspec

group :development do
  gem 'smart_proxy', github: 'theforeman/smart-proxy', ref: ENV['SMART_PROXY_BRANCH']
  #gem 'smart_proxy', path: '../smart-proxy'
  gem 'pry'
  gem 'pry-byebug'
end

group :test do
  gem 'minitest'
  gem 'mocha'
end
