# frozen_string_literal: true
module Ossert
  module Classifiers
    class Base
      # @return [Hash] the configuration of Cluster classifier.
      def self.config
        fail NotImplementedError
      end

      # (see .config)
      def config
        self.class.config
      end

      # @return [Array] the list of reversed metrics from configuration.
      def self.reversed_metrics
        @reversed_metrics ||= config['reversed']
      end

      # (see .reversed_metrics)
      def reversed_metrics
        self.class.reversed_metrics
      end

      def initialize(*)
        @classifiers = CLASSIFIERS.each_with_object({}) do |classifier_name, classifiers|
          classifiers[classifier_name] = GRADES.map { |grade| [grade, {}] }.to_h
        end
      end

      # @return [true, false] the check if all classifiers are exist and
      #   initialized.
      def ready?
        CLASSIFIERS.map { |name| @classifiers[name].values }.flatten.all?(&:present?)
      end

      # Run a processor over current classifier state for given project.
      # (see Ossert::Classifier::Check.process_using)
      #
      # @return [Hash<Symbol, Hash>] the processing result for each of
      #   classifiers indexed by its name.
      def process_using(action, project, last_year_offset = 1)
        Check.send(action, config, project, @classifiers, last_year_offset)
      end

      # Run a `grade` processor over current classifier state for given
      # project (see #process_using).
      # The result for each classifier is just a grade.
      def grade(*args)
        process_using(*args.unshift(:grade))
      end

      # Run a `check` processor over current classifier state for given
      # project (see #process_using).
      # The result for each classifier is a hash with grade and details.
      def check(*args)
        process_using(*args.unshift(:check))
      end

      # Prepare and return rules of qualification per metric for current
      # classifier state.
      #
      # @return [Hash<Symbol, Hash>] the structure of qualify rules indexed_by
      #   a classifier.
      def reference_values_per_grade
        SECTIONS.product(PERIODS).map do |section, period|
          ["#{section}_#{period}".to_sym, classifier_to_metrics_per_grade(section, period)]
        end.to_h
      end

      # Prepare and return rules for given section and a period metrics.
      #
      # @param section [#to_s] the name of data section
      # @param period [#to_s] the name of data period (e.g. :last_year, :total)
      # @return [Hash<String, Hash>] the rules to qualify each metric by grades.
      def classifier_to_metrics_per_grade(section, period)
        @classifiers["#{section}_#{period}".to_sym].each_with_object({}) do |(grade, metrics), res|
          metrics.each do |metric, value|
            (res[metric] ||= {})[grade] = value
          end
        end
      end

      # Run training process using current classifier state.
      #
      # @return [Hash<Symbol, Hash>] collection of classifiers for all combinations
      #   of data sections and periods.
      def train
        fail NotImplementedError
      end
    end
  end
end
