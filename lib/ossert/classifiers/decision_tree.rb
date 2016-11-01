# frozen_string_literal: true
require 'graphr'
require 'decisiontree'

module Ossert
  module Classifiers
    class DecisionTree
      GRADES = %w(
        ClassA
        ClassB
        ClassC
        ClassD
        ClassE
      ).freeze

      class << self
        attr_accessor :all

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

      SECTION_DATA = {
        agility_total: ->(project) { project.agility.total.metric_values },
        agility_last_year: ->(project) { project.agility.quarters.last_year_data },
        community_total: ->(project) { project.community.total.metric_values },
        community_last_year: ->(project) { project.community.quarters.last_year_data }
      }.freeze

      SECTION_METRICS = {
        agility_total: Stats::AgilityTotal.metrics,
        agility_last_year: Stats::AgilityQuarter.metrics,
        community_total: Stats::CommunityTotal.metrics,
        community_last_year: Stats::CommunityQuarter.metrics
      }.freeze

      [:community, :agility].each do |section|
        [:total, :last_year].each do |type|
          name = "#{section}_#{type}".to_sym
          define_method("#{name}_check") do |project|
            public_send("#{name}_dec_tree").predict(SECTION_DATA[name].call(project))
          end
        end
      end

      def ready?
        agility_total_dec_tree.presence &&
          agility_last_year_dec_tree.presence &&
          community_total_dec_tree.presence &&
          community_last_year_dec_tree.presence
      end

      def train
        data = initialize_data

        trees = SECTION_METRICS.map do |section, metrics|
          ::DecisionTree::ID3Tree.new(metrics, data[section], 'ClassE', :continuous)
        end.tap(&:train)

        @agility_total_dec_tree,
        @agility_last_year_dec_tree,
        @community_total_dec_tree,
        @community_last_year_dec_tree = trees
      end

      def initialize_data
        result = { agility_total: [], agility_last_year: [], community_total: [], community_last_year: [] }

        GRADES.each_with_object(train_group) do |grade, grouped_projects|
          grouped_projects[grade].each do |project|
            SECTION_DATA.each do |section, data_collector|
              result[section] << (data_collector.call(project) << grade)
            end
          end
        end

        result
      end
    end
  end
end
