# frozen_string_literal: true

module Ossert
  module Classifiers
    class Growing < Base
      class Classifier
        # @return [Hash] of classifier metrics values
        attr_reader :classifier

        # @return [Hash] of classifier configuration
        attr_reader :config

        # @return [Symbol] the classifier name
        attr_reader :name

        def initialize(classifier, config, name)
          @classifier = classifier
          @config = config
          @name = name
        end

        # Run training process for instance classifer.
        #
        # @return [Array] a pair of classifier name and its metrics
        #   qualification rules.
        def train
          run_aggregation
          run_syntetics
          run_values_to_ranges
          run_reverse

          [name, classifier]
        end

        # Run aggregation for each metric for given classifier
        # Now for aggregation the average from values is taken.
        #
        # @return not specified.
        def run_aggregation
          GRADES.each_with_index do |grade, idx|
            classifier[grade].each_pair do |metric, values|
              all_values = values
              all_values += classifier[GRADES[idx + 1]][metric] if (idx + 1) < GRADES.count

              classifier[grade][metric] =
                if all_values.count <= 2
                  values.max || 0
                else
                  (all_values.sum / all_values.count).round(2)
                end
            end
          end
        end

        # @return [Array<String>] the list of reversed metrics.
        def reversed_metrics
          @reversed_metrics ||= config['reversed']
        end

        # Run processing for syntetic metrics.
        # Syntetics are used to replace real metric values with thresholds that
        # are calculated beforehand somehow.
        #
        # @return not specified.
        def run_syntetics
          config['syntetics'].each do |synt_metric, values_ranges|
            real_values = classifier.values.map { |metrics| metrics[synt_metric] }.compact
            next if real_values.empty?

            # TODO: reorganize
            values_range = Array.wrap(values_ranges.fetch(name) { values_ranges.fetch('default') })
            values_range = values_range.reverse if reversed_metrics.include? synt_metric
            step_thresholds = syntetic_step_thresholds(values_range)

            GRADES.each_with_index do |grade, idx|
              classifier[grade][synt_metric] = step_thresholds[idx]
            end
          end
        end

        # Prepare thresholds step calculator for given values range.
        # There could be a case when values range is already fullfilled then
        # we obviously return values_range array.
        # On the other hand values range could have only min and max from a
        # range. For that case we calculate a step size from min & max and
        # return those steps for min to max as array.
        #
        # @return [Array<Float>] a list of calculated thresholds
        def syntetic_step_thresholds(values_range)
          return ->(idx) { values_range[idx] } if values_range.count == GRADES.count

          max, min = values_range.map(&:to_i)
          step = ((max - min) / GRADES.count.to_f).round(2)
          max.step(min, -step).to_a
        end

        # Transform classifier metric threshold values to hashes with threshold
        # and range covered.
        #
        # @return not specified.
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

        # Transform classifier values of reversed metrics to the correct state.
        # Odinary metric values should grow to show the best results that means
        # that they have a highest bar of the values that makes it the best.
        # For reversed metrics we should invert ranges as for them less values
        # are harder to achieve for a project and we don't have a limit for
        # value growth.
        #
        # @return not specified.
        def run_reverse
          reversed_metrics.each do |reversed_metric|
            GRADES.first(GRADES.count / 2).each do |grade|
              grade_metrics = classifier[grade]
              next unless grade_metrics[reversed_metric].present?

              reversed_grade_metrics = classifier[REVERSED_GRADES[grade]]

              reversed_grade_metrics[reversed_metric], grade_metrics[reversed_metric] =
                grade_metrics[reversed_metric], reversed_grade_metrics[reversed_metric]
            end
          end
        end
      end
    end
  end
end
