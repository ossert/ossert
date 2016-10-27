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
      def exist?(name)
        ::ProjectRepo.new(Ossert.rom)[name].present?
      end

      def random(count = 10)
        ::ProjectRepo.new(Ossert.rom).random(count)
      end

      def fetch_all(name, reference = Ossert::Saveable::UNUSED_REFERENCE)
        project = if (name_exception = ExceptionsRepo.new(Ossert.rom)[name])
                    new(name, name_exception.github_name, name, reference)
                  else
                    new(name, nil, name, reference)
                  end

        Ossert::Fetch.all project
        project.prepare_time_bounds!
        project.dump
        nil
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

    def prepare_time_bounds!(extended_start: nil, extended_end: nil)
      config = {
        base_value: {
          start: Time.now.utc,
          end: 20.years.ago
        },
        aggregation: {
          start: :min,
          end: :max
        },
        extended: {
          start: (extended_start || Time.now.utc).to_datetime,
          end: (extended_end || 20.years.ago).to_datetime
        }
      }

      agility.quarters.fullfill!
      community.quarters.fullfill!

      [:start, :end].map do |time_bound|
        [
          config[:base_value][time_bound],
          config[:extended][time_bound],
          agility.quarters.send("#{time_bound}_date"),
          community.quarters.send("#{time_bound}_date")
        ].send(
          config[:aggregation][time_bound]
        ).to_date
      end
    end

    def meta_to_json
      JSON.generate(meta)
    end

    class BaseStore
      attr_accessor :quarters, :total, :total_prediction, :quarter_prediction

      def initialize(quarters: nil, total: nil)
        @quarters = quarters || QuartersStore.new(self.class.quarter_stats_klass)
        @total = total || self.class.total_stats_klass.new
      end
    end

    class Agility < BaseStore
      class << self
        def quarter_stats_klass
          Stats::AgilityQuarter
        end

        def total_stats_klass
          Stats::AgilityTotal
        end
      end
    end

    class Community < BaseStore
      class << self
        def quarter_stats_klass
          Stats::CommunityQuarter
        end

        def total_stats_klass
          Stats::CommunityTotal
        end
      end
    end
  end
end
