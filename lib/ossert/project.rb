module Ossert
  class Project
    include Ossert::Saveable

    attr_accessor :name, :github_alias, :rubygems_alias,
                  :community, :agility, :reference,
                  :meta

    META_STUB = {
      homepage_url: nil,
      docs_url: nil,
      wiki_url: nil,
      source_url: nil,
      issue_tracker_url: nil,
      mailing_list_url: nil,
      authors: nil,
      top_10_contributors: Array.new,
      description: nil,
      current_version: nil,
      rubygems_url: nil,
      github_url: nil,
    }

    class << self
      def fetch_all(name, reference = Ossert::Saveable::UNUSED_REFERENCE)
        if (name_exception = ExceptionsRepo.new(Ossert.rom)[name])
          project = new(name, name_exception.github_name, name, reference)
        else
          project = new(name, nil, name, reference)
        end

        Ossert::Fetch.all project
        project.dump
        nil
      end

      def projects_by_reference
        load_referenced.group_by { |prj| prj.reference }
      end
    end

    def grade_by_growing_classifier
      raise unless Classifiers::Growing.current.ready?
      Classifiers::Growing.current.grade(self)
    end
    alias_method :grade_by_classifier, :grade_by_growing_classifier

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

    def assign_data(meta:, agility:, community:)
      @agility = agility
      @community = community
      @meta = meta
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
        },
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

    class Agility
      attr_accessor :quarters, :total, :total_prediction, :quarter_prediction

      def initialize(quarters: nil, total: nil)
        @quarters = quarters || QuartersStore.new(Stats::AgilityQuarter)
        @total = total || Stats::AgilityTotal.new
      end
    end

    class Community
      attr_accessor :quarters, :total, :total_prediction, :quarter_prediction

      def initialize(quarters: nil, total: nil)
        @quarters = quarters || QuartersStore.new(Stats::CommunityQuarter)
        @total = total || Stats::CommunityTotal.new
      end
    end
  end
end
