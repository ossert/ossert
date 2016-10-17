module Ossert
  module Stats
    class AgilityTotal < Base
      self.section = 'agility'
      self.section_type = 'total'
      create_attributes_accessors

      [
        :issues_closed, :issues_active, :issues_non_owner, :issues_with_contrib_comments,
        :pr_closed, :pr_active, :pr_non_owner, :pr_with_contrib_comments,
      ].each do |metric|
        type = metric.to_s.split('_').first
        define_method("#{metric}_percent") do
          value = public_send(metric)
          total_count = public_send("#{type}_all").count
          return 0 if total_count.zero?
          ((value.count.to_d / total_count.to_d) * 100).round(2)
        end
      end

      [
        :first_pr_date, :last_pr_date, :first_issue_date, :last_issue_date, :last_release_date,
      ].each do |metric|
        define_method("#{metric}_int") { public_send(metric).to_i }
      end

      [:issues_all, :pr_all, :stale_branches].each do |metric|
        define_method("#{metric}_count") { public_send(metric).count }
      end

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
        if last_pr_date.presence && last_issue_date.presence
          [last_pr_date, last_issue_date].max.to_i
        else
          last_pr_date.presence || last_issue_date.presence || 10.years.ago
        end
      end

      def life_period
        last_change = if last_pr_date.presence && last_issue_date.presence
                        [last_pr_date, last_issue_date].max
                      else
                        last_pr_date.presence || last_issue_date.presence
                      end

        return 0 if last_change.nil?

        first_change = if first_pr_date.presence && first_issue_date.presence
                        [first_pr_date, first_issue_date].min
                      else
                        last_pr_date.presence || last_issue_date.presence
                      end

        return 0 if first_change.nil?

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
