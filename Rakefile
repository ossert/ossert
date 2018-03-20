# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'sequel'

require 'bundler'
Bundler.require

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new
Dir.glob('lib/ossert/tasks/*.rake').each { |r| import r }

task default: %i[rubocop spec]
