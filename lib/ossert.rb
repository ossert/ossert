# frozen_string_literal: true
require 'ossert/version'
require 'sequel'
require 'active_support/all' # remove later, we use only quarters and index_by here
require 'json'
require 'oj'

require 'ossert/config'
Ossert::Config.load(:stats, :classifiers_growth, :classifiers_cluster, :translations, :descriptions)

require 'ossert/stats'
require 'ossert/quarters_store'
require 'ossert/saveable'
require 'ossert/presenters'
require 'ossert/project'
require 'ossert/fetch'
require 'ossert/reference'
require 'ossert/classifiers'
require 'ossert/workers'

module Ossert
  def init(database_url = nil)
    Sequel.connect(database_url || ENV.fetch('DATABASE_URL'))
    require 'ossert/repositories'
  end
  module_function :init

  def description(key)
    descriptions.fetch(key.to_s, "Description for '#{key}' - not found")
  end
  alias descr description
  module_function :descr

  def descriptions
    @descriptions ||= ::Settings['descriptions']
  end
  module_function :descriptions

  def translate(key)
    translations.fetch(key.to_s, "Translation for '#{key}' - not found")
  end
  alias t translate
  module_function :t

  def translations
    @translations ||= ::Settings['translations']
  end
  module_function :translations

  # The reserved GitHub name for a project not found on GitHub
  NO_GITHUB_NAME = '__unknown__'

  class TooLong
    def self.new
      Ossert::Stats::PER_YEAR_TOO_LONG
    end
  end

  class Zero
    def self.new
      0
    end
  end
end
