# frozen_string_literal: true
require 'ossert/classifiers/base'
require 'ossert/classifiers/decision_tree'
require 'ossert/classifiers/growing'
require 'ossert/classifiers/cluster'
require 'ossert/classifiers/check'

module Ossert
  module Classifiers
    # The list of available data sections.
    SECTIONS = %i(agility community)
    # The list of available data periods.
    PERIODS = %i(total quarter last_year)
    # The list of available classifiers.
    # It is calculated from all combinations of SECTIONS and PERIODS.
    CLASSIFIERS = SECTIONS.product(PERIODS).map { |s, p| "#{s}_#{p}".to_sym }

    # The list of available grades for a project and its metrics.
    GRADES = %w(ClassA ClassB ClassC ClassD ClassE).freeze
    # The map of available grades to its reversed version.
    REVERSED_GRADES = GRADES.zip(GRADES.reverse).to_h.freeze

    # Public: Prepare classifiers.
    # It warms up classifiers upon existing data.
    def train
      Growing.new.train
      Cluster.current.train
      # Stale. Very untrusty
      DecisionTree.new(Project.projects_by_reference).train
    end
    module_function :train

    # Helper class for threshold value to range conversion
    class ThresholdToRange
      def initialize(metric, value, grade, reversed: ->(_) { false })
        @metric = metric
        @value = value
        @grade = grade
        @reversed = reversed
      end

      # @return [Range] for the given instance
      def range
        if reversed?(@metric)
          Reversed.new(@value, @grade).range
        else
          Base.new(@value, @grade).range
        end
      end

      # Check the metric if it reversed.
      #
      # @param metric_name [String] to check.
      # @return [true, false] check result.
      def reversed?(metric_name)
        @reversed.(metric_name)
      end

      # Class for base threshold to range behavior
      class Base
        def initialize(value, grade)
          @value = value.to_f
          @grade = grade
        end

        # @return [Range] for current instance state
        def range
          start_value...end_value
        end

        private

        # @return [true, false] if current value is the worst one.
        def worst_value?
          @grade == worst_grade
        end

        # @return [one of GRADES] which to treat as the worst one.
        def worst_grade
          GRADES.last
        end

        # @return [Float] where to start the result range
        def start_value
          return -Float::INFINITY if worst_value?
          @value
        end

        # @return [Float] where to end the result range
        def end_value
          Float::INFINITY
        end
      end

      # Class for reversed threshold to range behavior
      class Reversed < Base
        # @return [one of GRADES] which to treat as the worst one.
        def worst_grade
          GRADES.first
        end

        # @return [Float] where to start the result range
        def start_value
          -Float::INFINITY
        end

        # @return [Float] where to end the result range
        def end_value
          return Float::INFINITY if worst_value?
          @value
        end
      end
    end
  end
end
