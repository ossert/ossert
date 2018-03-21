# frozen_string_literal: true

module Ossert
  module Classifiers
    class Check
      GRADES = %w[
        A
        B
        C
        D
        E
      ].freeze
      KLASS_2_GRADE = {
        'ClassA' => 'A',
        'ClassB' => 'B',
        'ClassC' => 'C',
        'ClassD' => 'D',
        'ClassE' => 'E'
      }.freeze

      class << self
        # Run a processor over current classifier state for given project.
        #
        # @param action [Symbol] the processor method name
        # @param project [Ossert::Project] the project upon which processor runs
        # @param last_year_offset [Numeric] the offset from current time in
        #   quarters (defaults to 1)
        # @return [Hash<Symbol, Hash>] the processing result for each of
        #   classifiers indexed by its name.
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

        # Run a `check` processor over current classifier state for given
        # project (see #process_using).
        # The result for each classifier is a hash with grade and details.
        def check(*args)
          process_using(*args.unshift(:grade_as_hash))
        end

        # Run a `grade` processor over current classifier state for given
        # project (see #process_using).
        # The result for each classifier is just a grade.
        def grade(*args)
          process_using(*args.unshift(:grade))
        end

        # Get a checker class from its name.
        #
        # @return [Ossert::Classifiers::Check::Base descendant]
        def check_class_by(check_name)
          Kernel.const_get(
            "Ossert::Classifiers::Check::#{check_name.capitalize}"
          )
        end
      end

      # Abstact class for checking project via classifiers.
      class Base
        def initialize(config, project, classifiers, last_year_offset = 1)
          @config = config
          @project = project
          @classifiers = classifiers
          @last_year_offset = last_year_offset
        end

        # @return [String] name of classifier metrics section.
        def classifier_section
          @classifier_section ||= self.class.name.split('::').last.downcase
        end

        # @return [Hash<String, Hash>] of metrics and its weights indexed by
        #   their period.
        def metrics
          return @metrics if defined? @metrics

          @metrics = @config['metrics'][classifier_section].map do |period, period_metrics|
            [
              period,
              period_metrics.map do |metric, weight|
                [metric, weight.to_d]
              end.to_h
            ]
          end.to_h
        end

        # @return [Decimal] max score for a project for current classifier section.
        def max_score
          @max_score ||= (metrics['last_year'].values.sum + metrics['total'].values.sum).to_d
        end

        # Run check for current state.
        #
        # @return [Hash] of check results.
        def check
          rates = GRADES.each_with_object({}) { |klass, res| res[klass] = 0.0.to_d }
          strategy.each do |(period, sections)|
            Array(sections).each do |section|
              rate(
                rates,
                metrics[period.to_s],
                @project.data_for(section: section, period: period, opts: { last_year_offset: @last_year_offset }),
                @classifiers.fetch("#{section}_#{period}".to_sym)
              )
            end
          end
          rates
        end

        # @return [String of Ossert::Classifier::GRADES] which fits the most.
        def grade
          grade_as_hash[:mark]
        end

        # @return [Hash<Symbol, [Float, String]>] of grade details.
        def grade_as_hash
          max = GRADES.count
          sum = -0.2
          check.sort.reverse.each do |(_, score)|
            sum += score
            sum -= 0.2 if score < trusted_probability
          end
          { score: sum, mark: GRADES[(max - sum).to_i] }
        end

        protected

        # @return [Float] which probability to treat as trusted
        #   when qualifing a project
        def trusted_probability
          @trusted_probability ||= @config['trusted_probability']
        end

        # Calculate rating for given metrics, dataset and classifiers.
        # Result rating is aggregated into rates object.
        #
        # @param rates [Hash<String, Float>] scores per grade before calculation
        # @param period_metrics [Hash<String, Float>] subset of metrics
        #   for a period
        # @param dataset [Hash<String, Float>] extracted from current project
        #   for a calculation
        # @param classifier [Hash<String, Hash>] used for calculation. Consists
        #   of rules for qualification per project class (e.g. `ClassA`)
        # @return not specified
        def rate(rates, period_metrics, dataset, classifier)
          classifier.each_pair do |klass, qualified_metrics|
            period_metrics.slice(*dataset.keys).each_pair do |metric, weight|
              range = qualified_metrics[metric.to_s][:range]
              rates[KLASS_2_GRADE[klass]] += weight / max_score if range.cover? dataset[metric].to_f
            end
          end
        end
      end

      # Popularity check processing for a project via classifiers.
      class Popularity < Base
        # @return [Hash<Symbol, Symbol>] period vs data sections processing
        #   strategy
        def strategy
          {
            last_year: :community,
            total: :community
          }
        end
      end

      # Maintenance check processing for a project via classifiers.
      class Maintenance < Base
        # @return [Hash<Symbol, Symbol>] period vs data sections processing
        #   strategy
        def strategy
          {
            last_year: :agility,
            total: :agility
          }
        end
      end

      # Maturity check processing for a project via classifiers.
      class Maturity < Base
        # @return [Hash<Symbol, Symbol>] period vs data sections processing
        #   strategy
        def strategy
          {
            last_year: %i[agility community],
            total: %i[agility community]
          }
        end
      end
    end
  end
end
