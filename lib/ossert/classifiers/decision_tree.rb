# frozen_string_literal: true
require 'graphr'
require 'decisiontree'

module Ossert
  module Classifiers
    class DecisionTree
      class << self
        attr_accessor :all

        # Prepare and return decision tree classifier instance for existing
        # refernce projects.
        #
        # @return [Ossert::Classifiers::DecisionTree] initialized cluster classifer
        def for_current_projects
          new(Project.projects_by_reference)
        end

        def current
          all.last
        end
      end

      def initialize(train_group)
        @train_group = train_group

        (self.class.all ||= []) << self
      end

      attr_reader :train_group
      attr_reader :agility_total_dec_tree,
                  :agility_last_year_dec_tree,
                  :community_total_dec_tree,
                  :community_total_dec_tree,
                  :community_last_year_dec_tree

      # Run a decision tree predict process for given project.
      #
      # @return [Hash] grades indexed by data section and period.
      def check(project)
        {
          agility: {
            total: agility_total_check(project),
            last_year: agility_last_year_check(project)
          },
          community: {
            total: community_total_check(project),
            last_year: community_last_year_check(project)
          }
        }
      end

      SECTION_METRICS = {
        agility_total: Stats::AgilityTotal.metrics,
        agility_last_year: Stats::AgilityQuarter.metrics,
        community_total: Stats::CommunityTotal.metrics,
        community_last_year: Stats::CommunityQuarter.metrics
      }.freeze

      [:community, :agility].each do |section|
        [:total, :last_year].each do |period|
          name = "#{section}_#{period}".to_sym
          define_method("#{name}_check") do |project|
            public_send("#{name}_dec_tree").predict(project.data_for(section: section, period: period).values)
          end
        end
      end

      # @return [true, false] the check if all classifiers are exist and
      #   initialized.
      def ready?
        agility_total_dec_tree.presence &&
          agility_last_year_dec_tree.presence &&
          community_total_dec_tree.presence &&
          community_last_year_dec_tree.presence
      end

      # Run training process using current classifier state.
      #
      # @return not specified
      def train
        data = initialize_data

        trees = SECTION_METRICS.map do |section, metrics|
          ::DecisionTree::ID3Tree.new(metrics, data[section], 'ClassE', :continuous)
        end
        trees.each(&:train)

        @agility_total_dec_tree,
        @agility_last_year_dec_tree,
        @community_total_dec_tree,
        @community_last_year_dec_tree = trees
      end

      # Initialize data for classifiers using data from train group projects.
      #
      # @return not specified
      def initialize_data
        result = {
          agility_total: [],
          agility_last_year: [],
          agility_quarter: [],
          community_total: [],
          community_last_year: [],
          community_quarter: []
        }

        GRADES.each_with_object(train_group) do |grade, grouped_projects|
          grouped_projects[grade].each do |project|
            SECTIONS.product(PERIODS).each do |section, period|
              classifier_name = "#{section}_#{period}".to_sym
              result[classifier_name] << (project.data_for(section: section, period: period).values << grade)
            end
          end
        end

        result
      end
    end
  end
end
