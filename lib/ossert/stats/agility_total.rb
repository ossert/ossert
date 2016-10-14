module Ossert
  module Stats
    class AgilityTotal
      class << self
        attr_accessor :attributes

        def attr_accessor *attrs
          self.attributes = Array attrs
          super
        end

        def metrics
          [
            :issues_active_percent, :issues_non_owner_percent, :issues_with_contrib_comments_percent, :issues_all_count,
            :issues_closed_percent,
            :pr_active_percent, :pr_non_owner_percent, :pr_with_contrib_comments_percent, :pr_all_count,
            :pr_closed_percent,
            :issues_processed_in_avg, :pr_processed_in_avg,
            :first_pr_date_int, :last_pr_date_int, :first_issue_date_int, :last_issue_date_int, :last_release_date_int,
            :releases_count, :commits_count_since_last_release_count,
            :last_year_commits, :life_period, :last_changed,
            :stale_branches_count
          ]
        end
      end

      # #### Stats, total for all time
      # - Merged PRs
      # - Opened non-author Issues, "with author comments" and total count
      # - Issues "no:assignee" "no:milestone" to total count
      # - Amount of changes each quarter (Graph? -> Later)
      attr_accessor :issues_open, :issues_closed, :issues_owner, :issues_non_owner, :issues_with_contrib_comments, :issues_total,
                    :issues_processed_in_avg,
                    :pr_open, :pr_merged, :pr_closed, :pr_owner, :pr_non_owner, :pr_with_contrib_comments, :pr_total,
                    :pr_processed_in_avg,
                    :first_pr_date, :last_pr_date, :first_issue_date, :last_issue_date,
                    :releases_total_gh, :releases_total_rg, :last_release_date, :commits_count_since_last_release,
                    :last_year_commits, :stale_branches, :branches

      NON_SET_VARS = %w(first_pr_date last_pr_date first_issue_date last_issue_date last_release_date
                        commits_count_since_last_release last_year_commits issues_processed_in_avg pr_processed_in_avg)
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

      def initialize
        self.class.attributes.each do |var|
          next if NON_SET_VARS.include?(var.to_s)
          send "#{var}=", Set.new
        end
      end

      def metric_values
        self.class.metrics.map { |metric| public_send(metric).to_i }
      end

      def metrics_to_hash
        self.class.metrics.each_with_object({}) do |var, result|
          value = send(var)
          if value.is_a? Set
            result[var] = value.to_a
          else
            result[var] = value
          end
        end
      end

      def to_hash
        self.class.attributes.each_with_object({}) do |var, result|
          value = send(var)
          if value.is_a? Set
            result[var] = value.to_a
          else
            result[var] = value
          end
        end
      end

      def to_json
        JSON.generate(to_hash)
      end
    end
  end
end
