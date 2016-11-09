# frozen_string_literal: true
module Ossert
  module Stats
    class AgilityQuarter < Base
      self.section = 'agility'
      self.section_type = 'quarter'
      create_attributes_accessors

      define_percent(
        issues_active: :issues_all,
        issues_closed: :issues_all,
        pr_active: :pr_all,
        pr_closed: :pr_all,
        pr_merged: :pr_all,
        default_value: 100.0
      )

      define_counts(
        :issues_active, :pr_active, :issues_closed, :issues_actual,
        :pr_closed, :issues_all, :pr_all, :pr_actual
      )

      def issues_processed_in_median
        median(issues_processed_in_days, default_value: PER_QUARTER_TOO_LONG)
      end

      def issues_processed_in_avg
        return PER_QUARTER_TOO_LONG if (count = Array(issues_processed_in_days).size).zero?
        issues_processed_in_days.sum / count
      end

      def pr_processed_in_median
        median(pr_processed_in_days, default_value: PER_QUARTER_TOO_LONG)
      end

      def pr_processed_in_avg
        return PER_QUARTER_TOO_LONG if (count = Array(pr_processed_in_days).size).zero?
        pr_processed_in_days.sum / count
      end

      def issues_active
        (issues_open + issues_actual) - issues_closed
      end

      def issues_all
        issues_open + issues_closed + issues_actual
      end

      def pr_active
        (pr_open + pr_actual) - pr_closed
      end

      def pr_all
        pr_open + pr_closed + pr_actual
      end

      def releases_count
        [releases_total_rg.count, releases_total_gh.count].max
      end
    end
  end
end
