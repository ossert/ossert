# frozen_string_literal: true
require 'ossert/classifiers/base'
require 'ossert/classifiers/decision_tree'
require 'ossert/classifiers/growing'
require 'ossert/classifiers/cluster'
require 'ossert/classifiers/check'

module Ossert
  module Classifiers
    SECTIONS = %i(agility community)
    PERIODS = %i(total quarter last_year)
    CLASSIFIERS = SECTIONS.product(PERIODS).map { |s, p| "#{s}_#{p}".to_sym }

    GRADES = %w(
      ClassA
      ClassB
      ClassC
      ClassD
      ClassE
    ).freeze
    REVERSED_GRADE = {
      'ClassA' => 'ClassE',
      'ClassB' => 'ClassD',
      'ClassC' => 'ClassC',
      'ClassD' => 'ClassB',
      'ClassE' => 'ClassA'
    }.freeze

    # Public: Prepare classifiers.
    # It warms up classifiers upon existing data.
    def train
      Growing.new.train
      Cluster.current.train
      # Stale. Very untrusty
      # DecisionTree.new(projects_by_reference).train
    end
    module_function :train

    class ThresholdToRange
      def initialize(metric, value, grade, reversed: ->(_) { false })
        @metric = metric
        @value = value
        @grade = grade
        @reversed = reversed
      end

      def range
        if reversed?(@metric)
          Reversed.new(@value, @grade).range
        else
          Base.new(@value, @grade).range
        end
      end

      def reversed?(metric_name)
        @reversed.(metric_name)
      end

      class Base
        def initialize(value, grade)
          @value = value
          @full_range = (grade == last_grade)
        end

        def range
          return full_range if full_range?
          start_value...end_value
        end

        private

        def full_range?
          @full_range
        end

        def last_grade
          GRADES.last
        end

        def full_range
          -Float::INFINITY...Float::INFINITY
        end

        def start_value
          @value
        end

        def end_value
          Float::INFINITY
        end
      end

      class Reversed < Base
        def last_grade
          GRADES.first
        end

        def start_value
          -Float::INFINITY
        end

        def end_value
          @value
        end
      end
    end
  end
end
