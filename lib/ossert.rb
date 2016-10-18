require "ossert/version"
require 'gems'
require 'sequel'
require 'active_support/all' # remove later, we use only quarters and index_by here
require 'json'
require 'oj'

require 'weakref'
require "ossert/config"
Ossert::Config.load [:stats, :classifiers, :translations]
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
  def rom(database_url = nil)
    return @rom if defined? @rom
    conf = ROM::Configuration.new(:sql, database_url || ENV.fetch("DATABASE_URL"))
    conf.register_relation(Projects)
    conf.register_relation(Exceptions)
    @rom = ROM.container(conf)
  end
  module_function :rom

  def translate(key)
    translations.fetch(key.to_s, "Translation for '#{key}' - not found")
  end
  module_function :translate
  alias_method :t, :translate
  module_function :t

  def translations
    @translations ||= ::Settings['translations']
  end
  module_function :translations
end
