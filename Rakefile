# frozen_string_literal: true

require 'rake'
require 'rake/testtask'

begin
  require 'bundler/gem_tasks'
rescue LoadError
end

desc 'Default: run unit tests.'
task default: :test

desc 'Test Ansible plugin'
Rake::TestTask.new(:test) do |t|
  t.libs << '.'
  t.libs << 'lib'
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

namespace :jenkins do
  desc nil # No description means it's not listed in rake -T
  task unit: :test
end
