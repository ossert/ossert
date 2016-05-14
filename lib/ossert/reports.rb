require 'csv'

module Ossert
  module Reports
    class Total
      attr_reader :projects

      COMMUNITY_METRICS = [
        :users_creating_issues, :users_commenting_issues, :users_creating_pr, :users_commenting_pr,
        :contributors, :watchers, :stargazers, :forks,
        :owners_github, :owners_rubygems, :users_involved
      ]
      AGILITY_METRICS = [
        :issues_open, :issues_closed, :issues_owner, :issues_non_owner, :issues_with_contrib_comments, :issues_total,
        :pr_open, :pr_merged, :pr_closed, :pr_owner, :pr_non_owner, :pr_with_contrib_comments, :pr_total,
        :first_pr_date, :last_pr_date, :first_issue_date, :last_issue_date,
        :releases_total_gh, :releases_total_rg, :last_release_date, :commits_count_since_last_release,
        :last_year_commits, :stale_branches, :branches, :total_downloads
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

    class Pulse # Prepare data for Graph
      COMMUNITY_METRICS = [
        :users_creating_issues, :users_commenting_issues, :users_creating_pr, :users_commenting_pr,
        :stargazers, :forks, # NO DATES... FUUU... :watchers,
        :users_involved
      ]
      AGILITY_METRICS = [
        :issues_open, :issues_closed, :issues_total, :pr_open, :pr_closed, :pr_total,
        :releases_total_gh, :branches, :releases_total_rg, :commits,
        :download_divergence, :total_downloads, :delta_downloads
      ]
      attr_reader :projects

      def initialize(projects)
        @projects = projects
      end

      def report
        # METRIC1
        #
        # DATE | PR1-METRIC1 | PR2-METRIC1 |
        # DATE | PR1-METRIC1 | PR2-METRIC1 |
        # DATE | PR1-METRIC1 | PR2-METRIC1 |
        # DATE | PR1-METRIC1 | PR2-METRIC1 |
        # DATE | PR1-METRIC1 | PR2-METRIC1 |
        # DATE | PR1-METRIC1 | PR2-METRIC1 |
        #

        # METRIC2
        #
        # DATE | PR1-METRIC2 | PR2-METRIC2 |
        # DATE | PR1-METRIC2 | PR2-METRIC2 |
        # DATE | PR1-METRIC2 | PR2-METRIC2 |
        # DATE | PR1-METRIC2 | PR2-METRIC2 |
        # DATE | PR1-METRIC2 | PR2-METRIC2 |
        # DATE | PR1-METRIC2 | PR2-METRIC2 |

        # CSV.open("reports/projects-pulse.csv", "wb") do |csv|
        agility_start_date = Time.now
        agility_end_date = 20.years.ago
        community_start_date = Time.now
        community_end_date = 20.years.ago

        projects.each do |project|
          project.agility.quarters.fullfill!
          agility_start_date = [project.agility.quarters.start_date, agility_start_date].min
          agility_end_date = [project.agility.quarters.end_date, agility_end_date].max
          project.community.quarters.fullfill!
          community_start_date = [project.community.quarters.start_date, community_start_date].min
          community_end_date = [project.community.quarters.end_date, community_end_date].max
        end

        CSV.open("reports/projects-community-pulse.csv", "wb") do |csv|
          csv << ['Community Metrics']
          COMMUNITY_METRICS.each do |m|
            csv << ([m] | projects.map(&:name))
            community_start_date.to_i.step(community_end_date.to_i, 92.days.to_i) do |quarter|
              quarter_date = Time.at(quarter).beginning_of_quarter
              row = [quarter_date.strftime('%Y/%m/%d')]
              unknown = 0
              projects.each do |project|
                if quarter_date < project.community.quarters.start_date || quarter_date > project.community.quarters.end_date
                  row << 0
                  unknown += 1
                  next
                end

                val = project.community.quarters[quarter].send(m)
                val = val.count.to_s if val.is_a?(Set)
                row << (val.present? ? val.to_s : 0.0)
              end
              csv << row unless unknown == projects.length
            end
            csv << [' --- ']
          end
        end

        CSV.open("reports/projects-agility-pulse.csv", "wb") do |csv|
          csv << ['Agility Metrics']
          AGILITY_METRICS.each do |m|
            csv << ([m] | projects.map(&:name))
            agility_start_date.to_i.step(agility_end_date.to_i, 92.days.to_i) do |quarter|
              quarter_date = Time.at(quarter).beginning_of_quarter
              row = [quarter_date.strftime('%Y/%m/%d')]
              unknown = 0
              projects.each do |project|
                if quarter_date < project.agility.quarters.start_date || quarter_date > project.agility.quarters.end_date
                  row << 0
                  unknown += 1
                  next
                end

                val = project.agility.quarters[quarter].send(m)
                val = val.count.to_s if val.is_a?(Set)
                row << (val.present? ? val.to_s : 0.0)
              end
              csv << row unless unknown == projects.length
            end
            csv << [' --- ']
          end
        end
      end
    end
  end
end
