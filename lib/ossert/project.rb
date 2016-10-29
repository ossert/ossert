# frozen_string_literal: true
module Ossert
  class Project
    include Ossert::Saveable

    attr_accessor :name, :github_alias, :rubygems_alias,
                  :community, :agility, :reference,
                  :meta, :created_at, :updated_at

    META_STUB = {
      homepage_url: nil,
      docs_url: nil,
      wiki_url: nil,
      source_url: nil,
      issue_tracker_url: nil,
      mailing_list_url: nil,
      authors: nil,
      top_10_contributors: [],
      description: nil,
      current_version: nil,
      rubygems_url: nil,
      github_url: nil
    }.freeze

    class << self
      def fetch_all(name, reference = Ossert::Saveable::UNUSED_REFERENCE)
        project = find_by_name(name, reference)

        Ossert::Fetch.all project
        project.prepare_time_bounds!
        project.dump
      rescue => e
        puts "Fetching Failed for '#{name}' with error: #{e.inspect}"
      end

      def projects_by_reference
        load_referenced.group_by(&:reference)
      end
    end

    def grade_by_growing_classifier
      raise unless Classifiers::Growing.current.ready?
      Classifiers::Growing.current.grade(self)
    end
    alias grade_by_classifier grade_by_growing_classifier

    def analyze_by_decisision_tree
      raise unless Classifiers::DecisionTree.current.ready?
      Classifiers::DecisionTree.current.check(self)
    end

    def initialize(name, github_alias = nil, rubygems_alias = nil, reference = nil)
      @name = name.dup
      @github_alias = github_alias
      @rubygems_alias = (rubygems_alias || name).dup
      @reference = reference.dup

      @agility = Agility.new
      @community = Community.new
      @meta = META_STUB.dup
    end

    def assign_data(meta:, agility:, community:, created_at:, updated_at:)
      @agility = agility
      @community = community
      @meta = meta
      @created_at = created_at
      @updated_at = updated_at
    end

    def decorated
      @decorated ||= Ossert::Presenters::Project.new(self)
    end

    TIME_BOUNDS_CONFIG = {
      base_value: {
        start: nil,
        end: nil
      },
      aggregation: {
        start: :min,
        end: :max
      },
      extended: {
        start: nil,
        end: nil
      }
    }.freeze

    def prepare_time_bounds!(extended_start: nil, extended_end: nil)
      config = TIME_BOUNDS_CONFIG.dup
      config[:base_value][:start] = Time.now.utc
      config[:base_value][:end] = 20.years.ago
      config[:extended][:start] = (extended_start || Time.now.utc).to_datetime
      config[:extended][:end] = (extended_end || 20.years.ago).to_datetime

      agility.quarters.fullfill! && community.quarters.fullfill!

      [:start, :end].map { |time_bound| time_bound_values(time_bound, config).to_date }
    end

    def time_bound_values(time_bound, config)
      [
        config[:base_value][time_bound], config[:extended][time_bound],
        agility.quarters.send("#{time_bound}_date"), community.quarters.send("#{time_bound}_date")
      ].send(config[:aggregation][time_bound])
    end

    def meta_to_json
      JSON.generate(meta)
    end

    class BaseStore
      attr_accessor :quarters, :total, :total_prediction, :quarter_prediction

      def initialize(quarters: nil, total: nil)
        @quarters = quarters || QuartersStore.new(self.class.quarter_stats_klass_name)
        @total = total || ::Kernel.const_get(self.class.total_stats_klass_name).new
      end
    end

    class Agility < BaseStore
      class << self
        def quarter_stats_klass_name
          'Ossert::Stats::AgilityQuarter'
        end

        def total_stats_klass_name
          'Ossert::Stats::AgilityTotal'
        end
      end
    end

    class Community < BaseStore
      class << self
        def quarter_stats_klass_name
          'Ossert::Stats::CommunityQuarter'
        end

        def total_stats_klass_name
          'Ossert::Stats::CommunityTotal'
        end
      end
    end
  end
end
