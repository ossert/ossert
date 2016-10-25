module Ossert
  module Classifiers
    class Growing
      class Classifier
        GRADES = %w(ClassA ClassB ClassC ClassD ClassE)
        REVERSED_GRADE = {
          'ClassA' => 'ClassE',
          'ClassB' => 'ClassD',
          'ClassC' => 'ClassC',
          'ClassD' => 'ClassB',
          'ClassE' => 'ClassA'
        }

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
              sibling_class_values = if (idx + 1) < GRADES.count
                                       classifier[GRADES[idx+1]][metric]
                                     else
                                       []
                                     end
              all_values = sibling_class_values + values
              classifier[grade][metric] = (values.max || 0) and next if all_values.count <= 2
              classifier[grade][metric] = (all_values.sum/all_values.count).round(2)
            end
          end
        end

        def run_syntetics
          config['syntetics'].each do |synt_metric, values_range|
            real_values = classifier.values.map { |metrics| metrics[synt_metric] }.compact
            next if real_values.empty?

            values_range = Array.wrap(values_range)
            values_range = values_range.reverse if reversed_metrics.include? synt_metric

            max_value, min_value = values_range
            min_value = min_value.to_i
            max_value = max_value.to_i

            growth = ((max_value - min_value) / GRADES.count.to_f).round(2)

            GRADES.reverse.each_with_index do |grade, idx|
              classifier[grade][synt_metric] = (growth * (idx + 1)).round(2) + min_value
            end
          end
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
            @metric, @value, @grade = metric, value, grade
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
            GRADES.first((GRADES.count / 2.0).ceil).each do |grade|
              next unless classifier[grade][reversed_metric].present?

              previous_value = classifier[REVERSED_GRADE[grade]][reversed_metric]
              classifier[REVERSED_GRADE[grade]][reversed_metric] = classifier[grade][reversed_metric]
              classifier[grade][reversed_metric] = previous_value
            end
          end
        end
      end
    end
  end
end
