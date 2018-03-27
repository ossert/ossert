# frozen_string_literal: true

module Ossert
  module Twitter
    # Calculates moving average for all twitter metrics
    class MetricsAverager
      attr_reader :previous_date, :previous_metrics

      def initialize(previous_date:, previous_metrics:)
        @previous_date = previous_date
        @previous_metrics = previous_metrics
      end

      def call(next_date:, next_metrics:)
        next_metrics.each_with_object({}) do |(metric_name, new_value), hash|
          previous_value = previous_metrics[metric_name]

          hash[metric_name] = moving_average(
            days_passed: next_date - previous_date,
            previous_value: previous_value,
            next_value: new_value
          )
        end
      end

      private

      def moving_average(days_passed:, previous_value:, next_value:)
        (days_passed * previous_value + next_value) / (days_passed + 1).to_f
      end
    end
  end
end
