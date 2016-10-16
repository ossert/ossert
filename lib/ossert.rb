require "ossert/version"
require 'gems'
require 'sequel'
# interesting... https://rubygems.org/pages/data
# https://github.com/xmisao/bestgems.org/wiki/BestGems-API-v1-Specification
# http://bestgems.org/gems/gon
require 'active_support/all' # remove later, we use only quarters and index_by here
require 'json'
require 'oj'

require 'weakref'
require "ossert/config"
Ossert::Config.load
require "ossert/repositories"
require "ossert/stats"
require "ossert/quarters_store"
require "ossert/saveable"
require "ossert/presenters"
require "ossert/project"
require "ossert/fetch"
require "ossert/reports"
require "ossert/reference"
require "ossert/classifiers"
require 'octokit'

module Ossert
  def rom
    return @rom if defined? @rom
    conf = ROM::Configuration.new(:sql, ENV.fetch("DATABASE_URL"))
    conf.register_relation(Projects)
    conf.register_relation(Exceptions)
    @rom = ROM.container(conf)
  end
  module_function :rom
end
