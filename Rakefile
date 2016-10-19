require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'rom/sql/rake_task'

require 'bundler'
Bundler.require

RSpec::Core::RakeTask.new(:spec)
Dir.glob('lib/ossert/tasks/*.rake').each {|r| import r}

task :default => :spec
