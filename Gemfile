source 'https://rubygems.org'

gemspec

group :development do
  gem 'pry'

  if (smart_proxy_path = ENV.fetch('SMART_PROXY_PATH', nil))
    gem 'smart_proxy', path: smart_proxy_path
  elsif ENV.fetch('BUNDLE_SMART_PROXY', '1') != '0'
    gem 'smart_proxy', git: 'https://github.com/theforeman/smart-proxy',
                       branch: 'develop'
  end
end

group :test do
  gem 'minitest'
  gem 'mocha'
  gem 'theforeman-rubocop', '~> 0.1.0.pre'
end
