# frozen_string_literal: true
module Ossert
  module Classifiers
    class Growing
      class Classifier
        GRADES = [
          'ClassA'.freeze,
          'ClassB'.freeze,
          'ClassC'.freeze,
          'ClassD'.freeze,
          'ClassE'.freeze
        ].freeze
        REVERSED_GRADE = {
          'ClassA' => 'ClassE'.freeze,
          'ClassB' => 'ClassD'.freeze,
          'ClassC' => 'ClassC'.freeze,
          'ClassD' => 'ClassB'.freeze,
          'ClassE' => 'ClassA'.freeze
        }.freeze

        attr_reader :classifier, :config
        def initialize(classifier, config)
          @classifier = classifier
          @config = config
        end

        def train
          run_aggregation
          run_syntetics
          run_values_to_ranges
          run_reverse

          classifier
        end

        def run_aggregation
          GRADES.each_with_index do |grade, idx|
            classifier[grade].each_pair do |metric, values|
              sibling_class_values = []
              sibling_class_values = classifier[GRADES[idx + 1]][metric] if (idx + 1) < GRADES.count

              all_values = sibling_class_values + values
              (classifier[grade][metric] = (values.max || 0)) && next if all_values.count <= 2
              classifier[grade][metric] = (all_values.sum / all_values.count).round(2)
            end
          end
        end

        def run_syntetics
          config['syntetics'].each do |synt_metric, values_range|
            real_values = classifier.values.map { |metrics| metrics[synt_metric] }.compact
            next if real_values.empty?

            values_range = Array.wrap(values_range)
            values_range = values_range.reverse if reversed_metrics.include? synt_metric
            step_threshold = syntetic_step_threshold(values_range)

            GRADES.each_with_index do |grade, idx|
              classifier[grade][synt_metric] = step_threshold.call(idx)
            end
          end
        end

        def syntetic_step_threshold(values_range)
          return ->(idx) { values_range[idx] } if values_range.count == GRADES.count
          max_value, min_value = values_range
          min_value = min_value.to_i
          max_value = max_value.to_i
          step = ((max_value - min_value) / GRADES.count.to_f).round(2)
          ->(idx) { max_value - (step * idx).round(2) }
        end

        def run_values_to_ranges
          GRADES.each do |grade|
            classifier[grade].each_pair do |metric, value|
              classifier[grade][metric] = {
                threshold: value,
                range: ThresholdToRange.range_for(metric, value, grade)
              }
            end
          end
        end

        class ThresholdToRange
          def self.range_for(metric, value, grade)
            new(metric, value, grade).range
          end

          def initialize(metric, value, grade)
            @metric = metric
            @value = value
            @grade = grade
          end

          def range
            if reversed_metrics.include?(@metric)
              Reversed.new(@value, @grade).range
            else
              Base.new(@value, @grade).range
            end
          end

          def reversed_metrics
            @reversed_metrics ||= Ossert::Classifiers::Growing.config['reversed']
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

        def reversed_metrics
          @reversed_metrics ||= config['reversed']
        end

        def run_reverse
          reversed_metrics.each do |reversed_metric|
            GRADES.first(GRADES.count / 2).each do |grade|
              grade_metrics = classifier[grade]
              next unless grade_metrics[reversed_metric].present?
              reversed_grade_metrics = classifier[REVERSED_GRADE[grade]]

              reversed_grade_metrics[reversed_metric], grade_metrics[reversed_metric] =
                grade_metrics[reversed_metric], reversed_grade_metrics[reversed_metric]
            end
          end
        end
      end
    end
  end
end
