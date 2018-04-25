# frozen_string_literal: true

module Ossert
  module Twitter
    class Scheduler
      RATE_LIMIT = 180
      RATE_INTERVAL = 15.minutes

      FAULT_FACTOR = 0.75
      REQUESTS_PER_PROJECT = 1.3

      def call(projects)
        tokens_count = Ossert::Twitter::Credentials.access_tokens.count

        now = Time.now
        projects.each_with_index do |project, index|
          schedule_time = now + schedule_step * (index / tokens_count)
          Ossert::Workers::FetchTwitter.perform_at(schedule_time, project.name)
        end
      end

      def capacity_per_token(schedule_interval)
        (projects_per_seconds * schedule_interval.to_i).ceil
      end

      private

      def projects_per_seconds
        RATE_LIMIT * FAULT_FACTOR / REQUESTS_PER_PROJECT / RATE_INTERVAL
      end

      def schedule_step
        1.0 / projects_per_seconds
      end
    end
  end
end
