# frozen_string_literal: true

require 'ossert/version'
require 'sequel'
require 'active_support/all' # TODO: remove later
require 'json'
require 'oj'

require 'ossert/config'
Ossert::Config.load(:stats, :classifiers_growth, :classifiers_cluster, :translations, :descriptions, :fetchers)

require 'ossert/stats'
require 'ossert/quarters_store'
require 'ossert/saveable'
require 'ossert/presenters'
require 'ossert/project'
require 'ossert/fetch'
require 'ossert/reference'
require 'ossert/classifiers'
require 'ossert/workers'
require 'ossert/twitter'

module Ossert
  module_function

  def init(database_url = nil)
    Sequel.connect(database_url || ENV.fetch('DATABASE_URL'))
    require 'ossert/repositories'
  end

  def description(key)
    descriptions.fetch(key.to_s, "Description for '#{key}' - not found")
  end
  alias descr description

  def descriptions
    @descriptions ||= ::Settings['descriptions']
  end

  def translate(key)
    translations.fetch(key.to_s, "Translation for '#{key}' - not found")
  end
  alias t translate

  def translations
    @translations ||= ::Settings['translations']
  end

  # The reserved GitHub name for a project without GitHub link
  NO_GITHUB_NAME = '__unknown__'

  # The reserved GitHub name for a project not found on GitHub
  NOT_FOUND_GITHUB_NAME = '__not_found__'

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
