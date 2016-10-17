require 'graphr'
require 'decisiontree'

module Ossert
  module Classifiers
    class DecisionTree
      GRADES = %w(ClassA ClassB ClassC ClassD ClassE)

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
      attr_reader :agility_total_dec_tree, :agility_total_dec_tree, :agility_quarters_dec_tree,
                  :agility_quarters_dec_tree, :community_total_dec_tree, :community_total_dec_tree,
                  :community_quarters_dec_tree, :community_quarters_dec_tree

      def check(project)
        agility_total_prediction = agility_total_dec_tree.predict(project.agility.total.metric_values)
        agility_quarter_prediction = agility_quarters_dec_tree.predict(project.agility.quarters.last_year_data)
        community_total_prediction = community_total_dec_tree.predict(project.community.total.metric_values)
        community_quarter_prediction = community_quarters_dec_tree.predict(project.community.quarters.last_year_data)

        {
          agility: {
            total: agility_total_prediction,
            last_year: agility_quarter_prediction
          },
          community: {
            total: community_total_prediction,
            last_year: community_quarter_prediction
          }
        }
      end

      def ready?
        agility_total_dec_tree.presence &&
        agility_quarters_dec_tree.presence &&
        community_total_dec_tree.presence &&
        community_quarters_dec_tree
      end

      def train
        grouped_projects = train_group
        agility_total_attributes = Stats::AgilityQuarter.metrics
        agility_quarters_attributes = Stats::AgilityTotal.metrics
        community_total_attributes = Stats::CommunityTotal.metrics
        community_quarters_attributes = Stats::CommunityQuarter.metrics
        agility_total_data, community_total_data, agility_last_year_data, community_last_year_data = [], [], [], []

        GRADES.each_with_index do |grade, i|
          grouped_projects[grade].each do |project|
            agility_total_data << (project.agility.total.metric_values << grade)
            community_total_data << (project.community.total.metric_values << grade)
            if (last_year_data = project.agility.quarters.last_year_data).present?
              agility_last_year_data << (project.agility.quarters.last_year_data << grade)
            end
            if (last_year_data = project.community.quarters.last_year_data).present?
              community_last_year_data << (project.community.quarters.last_year_data << grade)
            end
          end
        end

        @agility_total_dec_tree = ::DecisionTree::ID3Tree.new(
          agility_total_attributes, agility_total_data, 'ClassE', :continuous
        )
        @agility_total_dec_tree.train
        @agility_quarters_dec_tree = ::DecisionTree::ID3Tree.new(
          agility_quarters_attributes, agility_last_year_data, 'ClassE', :continuous
        )
        @agility_quarters_dec_tree.train
        @community_total_dec_tree = ::DecisionTree::ID3Tree.new(
          community_total_attributes, community_total_data, 'ClassE', :continuous
        )
        @community_total_dec_tree.train
        @community_quarters_dec_tree = ::DecisionTree::ID3Tree.new(
          community_quarters_attributes, community_last_year_data, 'ClassE', :continuous
        )
        @community_quarters_dec_tree.train
      end
    end
  end
end
