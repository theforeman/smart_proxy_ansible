# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development do
  gem 'pry'
  gem 'pry-byebug'
end

group :rubocop do
  gem 'rubocop', '~> 1.28.0', require: false
  gem 'rubocop-minitest', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rake', require: false
end

group :test do
  gem 'minitest', require: false
  gem 'minitest-reporters', '~> 1.4', require: false
  gem 'mocha', '~> 1', require: false
  gem 'rake', '~> 13.0', require: false
  gem 'smart_proxy', github: 'theforeman/smart-proxy', branch: 'develop'
  gem 'webmock', '~> 3', require: false
end
