# frozen_string_literal: true
module Ossert
  module Classifiers
    class Base
      def self.config
        fail NotImplementedError
      end

      def config
        self.class.config
      end

      def self.reversed_metrics
        @reversed_metrics ||= config['reversed']
      end

      def reversed_metrics
        self.class.reversed_metrics
      end

      def initialize(*)
        @classifiers = CLASSIFIERS.each_with_object({}) do |classifier_name, classifiers|
          classifiers[classifier_name] = GRADES.map { |grade| [grade, {}] }.to_h
        end
      end

      def ready?
        CLASSIFIERS.map { |name| @classifiers[name].values }.flatten.all?(&:present?)
      end

      def process_using(action, project, last_year_offset = 1)
        Check.send(action, config, project, @classifiers, last_year_offset)
      end

      def grade(*args)
        process_using(*args.unshift(:grade))
      end

      def check(*args)
        process_using(*args.unshift(:check))
      end

      def reference_values_per_grade
        SECTIONS.product(PERIODS).map do |section, period|
          ["#{section}_#{period}".to_sym, classifier_to_metrics_per_grade(section, period)]
        end.to_h
      end

      def classifier_to_metrics_per_grade(section, period)
        @classifiers["#{section}_#{period}".to_sym].each_with_object({}) do |(grade, metrics), res|
          metrics.each do |metric, value|
            (res[metric] ||= {})[grade] = value
          end
        end
      end

      def train
        fail NotImplementedError
      end
    end
  end
end
