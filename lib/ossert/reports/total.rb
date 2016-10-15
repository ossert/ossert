module Ossert
  module Reports
    class Total
      attr_reader :projects

      # COMMUNITY_METRICS = [
      #   :users_creating_issues, :users_commenting_issues, :users_creating_pr, :users_commenting_pr,
      #   :contributors, :watchers, :stargazers, :forks,
      #   :owners_github, :owners_rubygems, :users_involved
      # ]
      # AGILITY_METRICS = [
      #   :issues_open, :issues_closed, :issues_owner, :issues_non_owner, :issues_with_contrib_comments, :issues_total,
      #   :pr_open, :pr_merged, :pr_closed, :pr_owner, :pr_non_owner, :pr_with_contrib_comments, :pr_total,
      #   :first_pr_date, :last_pr_date, :first_issue_date, :last_issue_date,
      #   :releases_total_gh, :releases_total_rg, :last_release_date, :commits_count_since_last_release,
      #   :last_year_commits, :stale_branches, :branches, :total_downloads
      # ]

      # 'Downloads Count', 'Releases Count', 'Issues Count', 'Pulls Count', 'Issues Open %', 'Pulls Open %', 'First to last issue period (in months)', 'Last Year Commits Count',
      #
      # 'Users Creating Issues Count', 'Users Commenting Issues Count', 'Users Creating Pulls Count', 'Users Commenting Pulls Count', 'Total Users Involved Count'
      COMMUNITY_METRICS = [
        :users_creating_issues_count, :users_commenting_issues_count,
        :users_creating_pr_count, :users_commenting_pr_count,
        :users_involved_count
      ]
      AGILITY_METRICS = [
        :issues_total_count, :issues_open_percent, :life_period_months,
        :pr_total_count, :pr_open_percent,
        :releases_count, :last_release_date,
        :last_year_commits, :total_downloads
      ]

      def initialize(projects)
        @projects = projects
      end

      def report
        CSV.open("reports/projects.csv", "wb") do |csv|
          csv << ['Community Metrics']
          csv << (['PROJECT/METRICS'] | COMMUNITY_METRICS.map(&:to_s))

          projects.each do |project|
            row = [project.name]
            COMMUNITY_METRICS.each do |m|
              val = project.community.total.send(m)
              val = val.count.to_s if val.is_a?(Set)
              row << (val.present? ? val.to_s : 'None')
            end
            csv << row
          end

          csv << [' ']
          csv << ['Agility Metrics']
          csv << (['PROJECT/METRICS'] | AGILITY_METRICS.map(&:to_s))
          projects.each do |project|
            row = [project.name]
            AGILITY_METRICS.each do |m|
              val = project.agility.total.send(m)
              val = val.count.to_s if val.is_a?(Set)
              row << (val.present? ? val.to_s : 'None')
            end
            csv << row
          end
        end
      end
    end
  end
end
