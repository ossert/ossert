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
        agility_total_data,
        community_total_data,
        agility_last_year_data,
        community_last_year_data = [], [], [], []

        grouped_projects = train_group
        GRADES.each do |grade|
          grouped_projects[grade].each do |project|
            agility_total_data << (project.agility.total.metric_values << grade)
            community_total_data << (project.community.total.metric_values << grade)

            if (last_year_data = project.agility.quarters.last_year_data).present?
              agility_last_year_data << (last_year_data << grade)
            end
            if (last_year_data = project.community.quarters.last_year_data).present?
              community_last_year_data << (last_year_data << grade)
            end
          end
        end

        trees = [
          [Stats::AgilityQuarter.metrics, agility_total_data],
          [Stats::AgilityTotal.metrics, agility_last_year_data],
          [Stats::CommunityTotal.metrics, community_total_data],
          [Stats::CommunityQuarter.metrics, community_last_year_data],
        ].map do |attributes, data|
          ::DecisionTree::ID3Tree.new(
            attributes, data, 'ClassE', :continuous
          )
        end.tap(&:train)

        @agility_total_dec_tree,
        @agility_quarters_dec_tree,
        @community_total_dec_tree,
        @community_quarters_dec_tree = trees
      end
    end
  end
end
