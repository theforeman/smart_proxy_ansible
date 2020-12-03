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
