# frozen_string_literal: true

require 'sequel'

module Ossert
  module Twitter
    # Updates twitter metrics to dabase and with moving averaging
    class MetricsUpdater
      attr_reader :project

      def initialize(project)
        @project = project
      end

      def call(date:, metrics:)
        base_attrs = { date: canonical(date), project_id: project.id }

        TwitterMetrics.db.transaction do
          metrics_record = TwitterMetrics.where(base_attrs).for_update.first
          if metrics_record.nil?
            create_metrics(base_attrs, metrics)
          else
            update_metrics(metrics_record, date, metrics)
          end
        end
      end

      private

      def create_metrics(base_attrs, metrics)
        TwitterMetrics.create(base_attrs.merge(metrics))
      end

      def update_metrics(record, date, metrics)
        record.update(
          Ossert::Twitter::MetricsAverager
            .new(previous_date: canonical(date), previous_metrics: record.values)
            .call(next_date: date, next_metrics: metrics)
        )
      end

      def canonical(date)
        date.monday
      end
    end
  end
end
