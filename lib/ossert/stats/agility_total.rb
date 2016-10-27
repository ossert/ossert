# frozen_string_literal: true
module Ossert
  module Stats
    class AgilityTotal < Base
      self.section = 'agility'
      self.section_type = 'total'
      create_attributes_accessors

      define_percent(
        :issues_closed, :issues_active, :issues_non_owner, :issues_with_contrib_comments,
        :pr_closed, :pr_active, :pr_non_owner, :pr_with_contrib_comments
      )

      [
        :first_pr_date, :last_pr_date, :first_issue_date,
        :last_issue_date, :last_release_date
      ].each do |metric|
        define_method("#{metric}_int") { public_send(metric).to_i }
      end

      define_counts(:issues_all, :pr_all, :stale_branches, :dependencies)

      def commits_count_since_last_release_count
        commits_count_since_last_release.is_a?(Set) ? 0 : commits_count_since_last_release
      end

      def issues_active
        issues_open - issues_closed
      end

      def issues_all
        issues_open + issues_closed
      end

      def pr_active
        pr_open - pr_closed
      end

      def pr_all
        pr_open + pr_closed
      end

      def last_changed
        [last_pr_date.presence, last_issue_date.presence].compact.max || 10.years.ago
      end

      def life_period
        last_change = [last_pr_date.presence, last_issue_date.presence].compact.max
        return 0 unless last_change

        first_change = [first_pr_date, first_issue_date].compact.min
        return 0 unless first_change

        (last_change - first_change).to_i
      end

      def life_period_months
        life_period / 1.month
      end

      def releases_count
        [releases_total_rg.count, releases_total_gh.count].max
      end
    end
  end
end
