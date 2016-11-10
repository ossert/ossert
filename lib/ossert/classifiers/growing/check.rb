# frozen_string_literal: true
module Ossert
  module Classifiers
    class Growing
      class Check
        GRADES = %w(
          A
          B
          C
          D
          E
        ).freeze
        KLASS_2_GRADE = {
          'ClassA' => 'A',
          'ClassB' => 'B',
          'ClassC' => 'C',
          'ClassD' => 'D',
          'ClassE' => 'E'
        }.freeze

        class << self
          def process_using(action, config, project, classifiers, last_year_offset = 1)
            checks_rates = config['checks'].map do |check_name|
              [
                check_name.to_sym,
                check_class_by(check_name).new(
                  config, project, classifiers, last_year_offset
                ).send(action)
              ]
            end
            checks_rates.to_h
          end

          def check(*args)
            process_using(*args.unshift(:grade_as_hash))
          end

          def grade(*args)
            process_using(*args.unshift(:grade))
          end

          def check_class_by(check_name)
            Kernel.const_get(
              "Ossert::Classifiers::Growing::Check::#{check_name.capitalize}"
            )
          end
        end

        class Base
          def initialize(config, project, classifiers, last_year_offset = 1)
            @config = config
            @project = project
            @classifiers = classifiers
            @last_year_offset = last_year_offset
          end

          def metrics_type
            self.class.name.split('::').last.downcase
          end

          def metrics
            return @metrics if defined? @metrics

            @metrics = @config['metrics'][metrics_type].map do |section, section_metrics|
              [
                section,
                section_metrics.map do |metric, weight|
                  [metric, weight.to_d]
                end.to_h
              ]
            end.to_h
          end

          def max_gain
            @max_gain ||= (metrics['last_year'].values.sum + metrics['total'].values.sum).to_d
          end

          def community_last_year_data
            @community_last_year_data ||= @project.community.quarters.last_year_as_hash(@last_year_offset)
          end

          def community_total_data
            @community_total_data ||= @project.community.total.metrics_to_hash
          end

          def agility_last_year_data
            @agility_last_year_data ||= @project.agility.quarters.last_year_as_hash(@last_year_offset)
          end

          def agility_total_data
            @agility_total_data ||= @project.agility.total.metrics_to_hash
          end

          def check
            rates = GRADES.each_with_object({}) { |klass, res| res[klass] = 0.0.to_d }
            strategy.each do |(section_type, data_types)|
              Array(data_types).each do |data_type|
                rate(
                  rates, metrics[section_type.to_s], send("#{data_type}_#{section_type}_data"),
                  @classifiers.fetch("#{data_type}_#{section_type}".to_sym)
                )
              end
            end
            rates
          end

          def grade
            max = GRADES.count
            sum = -0.6
            check.sort.reverse.each do |(_, gain)|
              sum += gain
              sum += 0.1 if gain > trusted_probability
            end
            GRADES[(max - sum).to_i]
          end

          def grade_as_hash
            max = GRADES.count
            sum = -0.6
            check.sort.reverse.each do |(_, gain)|
              sum += gain
              sum += 0.1 if gain > trusted_probability
            end
            { gain: sum, mark: GRADES[(max - sum).to_i] }
          end

          protected

          def trusted_probability
            @trusted_probability ||= @config['trusted_probability']
          end

          def rate(rates, metrics, data, classifier)
            classifier.each_pair do |klass, qualified_metrics|
              metrics.slice(*data.keys).each_pair do |metric, weight|
                range = qualified_metrics[metric.to_s][:range]
                rates[KLASS_2_GRADE[klass]] += weight / max_gain if range.cover? data[metric].to_f
              end
            end
          end
        end

        class Popularity < Base
          def strategy
            {
              last_year: :community,
              total: :community
            }
          end
        end

        class Maintenance < Base
          def strategy
            {
              last_year: :agility,
              total: :agility
            }
          end
        end

        class Maturity < Base
          def strategy
            {
              last_year: [:agility, :community],
              total: [:agility, :community]
            }
          end
        end
      end
    end
  end
end
