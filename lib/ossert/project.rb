require "ossert/project_decorator"

module Ossert
  class Project
    attr_accessor :name, :gh_alias, :rg_alias,
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

    def analyze_by_growing_classifier
      raise unless Classifiers::Growing.current.ready?
      Classifiers::Growing.current.check(self)
    end

    def analyze_by_decisision_tree
      raise unless Classifiers::DecisionTree.current.ready?
      Classifiers::DecisionTree.current.check(self)
    end

    def initialize(name, gh_alias = nil, rg_alias = nil, reference = nil, meta: nil, agility: nil, community: nil)
      @name = name.dup
      @gh_alias = gh_alias
      @rg_alias = (rg_alias || name).dup
      @agility = agility || Agility.new
      @community = community || Community.new
      @reference = reference.dup
      @meta = meta || META_STUB.dup
    end

    def decorated
      @decorated ||= Ossert::ProjectDecorator.new(self)
    end

    def repo
      ProjectRepo.new(Ossert.rom)
    end

    def meta_to_json
      JSON.generate(meta)
    end

    # TODO: dump any attribute
    def dump_meta
      current_repo = repo
      saved = current_repo[name]
      if saved
        current_repo.update(
          name,
          meta_data: meta_to_json,
        )
      else
        raise 'Not saved yet, sorry!'
      end
    end

    def dump
      current_repo = repo
      saved = current_repo[name]
      if saved
        current_repo.update(
          name,
          name: name,
          github_name: gh_alias,
          rubygems_name: rg_alias,
          reference: reference,
          meta_data: meta_to_json,
          agility_total_data: agility.total.to_json,
          agility_quarters_data: agility.quarters.to_json,
          community_total_data: community.total.to_json,
          community_quarters_data: community.quarters.to_json
        )
      else
        current_repo.create(
          name: name,
          github_name: gh_alias,
          rubygems_name: rg_alias,
          reference: reference,
          meta_data: meta_to_json,
          agility_total_data: agility.total.to_json,
          agility_quarters_data: agility.quarters.to_json,
          community_total_data: community.total.to_json,
          community_quarters_data: community.quarters.to_json
        )
      end
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

    class << self
      include Ossert::Saveable

      def fetch_all(name, reference = Ossert::Saveable::UNUSED_REFERENCE)
        name = name.dup
        reference = reference.dup
        name_exception = ExceptionsRepo.new(Ossert.rom)[name]
        if name_exception
          prj = new(name, name_exception.github_name, name, reference)
        else
          prj = new(name, nil, name, reference)
        end
        Ossert::Fetch.all prj
        prj.dump
        nil
      end

      def projects_by_reference
        load_referenced.group_by { |prj| prj.reference }
      end
    end
  end
end
