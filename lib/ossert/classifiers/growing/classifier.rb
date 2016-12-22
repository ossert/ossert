# frozen_string_literal: true
module Ossert
  module Classifiers
    class Growing < Base
      class Classifier
        attr_reader :classifier, :config, :name
        def initialize(classifier, config, name)
          @classifier = classifier
          @config = config
          @name = name
        end

        def train
          run_aggregation
          run_syntetics
          run_values_to_ranges
          run_reverse

          [name, classifier]
        end

        def run_aggregation
          GRADES.each_with_index do |grade, idx|
            classifier[grade].each_pair do |metric, values|
              all_values = values
              if (idx + 1) < GRADES.count
                all_values += classifier[GRADES[idx + 1]][metric]
              end

              classifier[grade][metric] =
                if all_values.count <= 2
                  values.max || 0
                else
                  (all_values.sum / all_values.count).round(2)
                end
            end
          end
        end

        def reversed_metrics
          @reversed_metrics ||= config['reversed']
        end

        def run_syntetics
          config['syntetics'].each do |synt_metric, values_ranges|
            real_values = classifier.values.map { |metrics| metrics[synt_metric] }.compact
            next if real_values.empty?

            # TODO: reorganize
            values_range = Array.wrap(values_ranges.fetch(name) { values_ranges.fetch('default') })
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
                range: ThresholdToRange.new(
                  metric, value, grade, reversed: ->(m) { reversed_metrics.include?(m) }
                ).range
              }
            end
          end
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
