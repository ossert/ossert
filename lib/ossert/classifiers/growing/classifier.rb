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
          config['syntetics'].each do |synt_metric, best_value|
            real_values = classifier.values.map { |metrics| metrics[synt_metric] }.compact
            next if real_values.empty?

            best_value ||= real_values.max

            growth = (best_value / GRADES.count.to_f).round(2)
            GRADES.reverse.each_with_index do |grade, idx|
              classifier[grade][synt_metric] = (growth * (idx + 1)).round(2)
            end
          end
        end

        def run_values_to_ranges
          GRADES.each_with_index do |grade, idx|
            classifier[grade].each_pair do |metric, value|
              reversed = reversed_metrics.include? metric
              any_value_idx = reversed ? 0 : GRADES.count - 1

              if idx == any_value_idx
                start_value, end_value = -Float::INFINITY, Float::INFINITY
              else
                start_value = reversed ? -Float::INFINITY : value
                end_value = reversed ? value : Float::INFINITY
              end

              classifier[grade][metric] = {
                threshold: value,
                range: start_value...end_value
              }
            end
          end
        end

        def reversed_metrics
          @reversed_metrics ||= config['reversed']
        end

        def run_reverse
          reversed_metrics.each do |reversed_metric|
            GRADES.first((GRADES.count / 2.0).ceil).each_with_index do |grade, idx|
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
