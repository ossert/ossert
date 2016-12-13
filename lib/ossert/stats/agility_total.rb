# frozen_string_literal: true
module Ossert
  module Stats
    class AgilityTotal < Base
      self.section = 'agility'
      self.section_type = 'total'
      create_attributes_accessors

      define_percent(
        issues_active:                :issues_all,
        issues_closed:                :issues_all,
        issues_non_owner:             :issues_all,
        issues_with_contrib_comments: :issues_all,
        pr_active:                    :pr_all,
        pr_closed:                    :pr_all,
        pr_non_owner:                 :pr_all,
        pr_with_contrib_comments:     :pr_all,
        default_value: 100.0
      )

      define_ints(
        :first_pr_date, :last_pr_date, :first_issue_date,
        :last_issue_date, :last_release_date
      )

      define_counts(:issues_all, :pr_all, :stale_branches, :dependencies)

      def commits_count_since_last_release_count
        commits_count_since_last_release.is_a?(Array) ? 0 : commits_count_since_last_release
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
        last_change = ([last_pr_date.to_i, last_issue_date.to_i] - [0]).max
        return 0 unless last_change

        first_change = ([first_pr_date.to_i, first_issue_date.to_i] - [0]).min
        return 0 unless first_change

        (Time.at(last_change) - Time.at(first_change)).to_i
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
