module Ossert
  module Reports
    class Pulse # Prepare data for Graph
      # COMMUNITY_METRICS = [
      #   :users_creating_issues, :users_commenting_issues, :users_creating_pr, :users_commenting_pr,
      #   :stargazers, :forks, # NO DATES... FUUU... :watchers,
      #   :users_involved
      # ]
      # AGILITY_METRICS = [
      #   :issues_open, :issues_closed, :issues_total, :pr_open, :pr_closed, :pr_total,
      #   :releases_total_gh, :branches, :releases_total_rg, :commits,
      #   :download_divergence, :total_downloads, :delta_downloads
      # ]
      COMMUNITY_METRICS = [
        :users_creating_issues_count, :users_commenting_issues_count,
        :users_creating_pr_count, :users_commenting_pr_count,
        :users_involved_count
      ]
      AGILITY_METRICS = [
        :issues_total_count, :issues_closed_count,
        :pr_total_count, :pr_closed_count,
        :releases_count,
        :commits,
        :total_downloads
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
        agility_start_date = Time.now.utc
        agility_end_date = 20.years.ago
        community_start_date = Time.now.utc
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
            community_start_date.to_i.step(community_end_date.to_i, 93.days.to_i) do |quarter|
              quarter_date = Time.at(quarter).to_date.to_time('utc').beginning_of_quarter
              quarter = quarter_date.to_i
              row = [quarter_date.strftime('%Y/%m/%d')]
              unknown = 0
              projects.each do |project|
                if quarter_date < project.community.quarters.start_date || quarter_date > project.community.quarters.end_date
                  row << 0
                  unknown += 1
                  next
                end

                val = project.community.quarters.fetch(quarter).send(m)
                val = val.count.to_s if val.is_a?(Set)
                row << (val.present? ? val.to_s : 0)
                unknown += 1 if val.to_i == 0
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
            agility_start_date.to_i.step(agility_end_date.to_i, 93.days.to_i) do |quarter|
              quarter_date = Time.at(quarter).to_date.to_time('utc').beginning_of_quarter
              quarter = quarter_date.to_i
              row = [quarter_date.strftime('%Y/%m/%d')]
              unknown = 0
              projects.each do |project|
                if quarter_date < project.agility.quarters.start_date || quarter_date > project.agility.quarters.end_date
                  row << 0
                  unknown += 1
                  next
                end

                val = project.agility.quarters.fetch(quarter).send(m)
                val = val.count.to_s if val.is_a?(Set)
                row << (val.present? ? val.to_s : 0.0)
                unknown += 1 if val.to_i == 0
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
