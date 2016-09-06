module Ossert
  module Classifiers
    class Growing
      CLASSES = %w(ClassA ClassB ClassC ClassD ClassE)
      SYNTETIC = [:download_divergence, :pr_active_percent, :issues_active_percent]

      class << self
        attr_accessor :all

        def for_current_projects
          new(Project.projects_by_reference)
        end

        def current
          all.last
        end
      end

      def initialize(train_group)
        @train_group = train_group

        (self.class.all ||= []) << self
      end

      attr_reader :train_group
      attr_reader :agility_total_classifier, :community_total_classifier,
                  :agility_quarter_classifier, :community_quarter_classifier

      def ready?
        agility_total_classifier.keys == CLASSES && community_total_classifier.keys == CLASSES
      end

      def reversed(klass)
        {
          'ClassA' => 'ClassE',
          'ClassB' => 'ClassD',
          'ClassC' => 'ClassC',
          'ClassD' => 'ClassB',
          'ClassE' => 'ClassA',
        }[klass]
      end

      # Maybe add syntetic attributes. Take maximum as a start and go less. from A to E... and reversed

      def reference_values_per_class
        reversed = [
          :issues_active_percent, :pr_active_percent
        ]
        agility_total = agility_total_classifier.each_with_object({}) do |(ref_class, metrics), res|
          metrics.each do |metric, value|
            if reversed.include? metric
              (res[metric] ||= {})[reversed(ref_class)] = value
            else
              (res[metric] ||= {})[ref_class] = value
            end
          end
        end
        agility_quarter = agility_quarter_classifier.each_with_object({}) do |(ref_class, metrics), res|
          metrics.each do |metric, value|
            if reversed.include? metric
              (res[metric] ||= {})[reversed(ref_class)] = value
            else
              (res[metric] ||= {})[ref_class] = value
            end
          end
        end
        community_total = community_total_classifier.each_with_object({}) do |(ref_class, metrics), res|
          metrics.each do |metric, value|
            (res[metric] ||= {})[ref_class] = value
          end
        end
        community_quarter = community_quarter_classifier.each_with_object({}) do |(ref_class, metrics), res|
          metrics.each do |metric, value|
            (res[metric] ||= {})[ref_class] = value
          end
        end
        {
          agility_total: agility_total,
          agility_quarter: agility_quarter,
          community_total: community_total,
          community_quarter: community_quarter
        }
      end

      def check(project)
        agility_total_results = CLASSES.each_with_object({}) { |klass, res| res[klass] = 0.0 }
        community_total_results = agility_total_results.dup
        agility_quarter_results = agility_total_results.dup
        community_quarter_results = agility_total_results.dup

        half_metrics = [:issues_non_owner_percent, :pr_non_owner_percent,
                        :pr_closed_percent, :issues_closed_percent,
                        :pr_with_contrib_comments_percent, :issues_with_contrib_comments_percent]

        full_metrics = [
          # Absolute:
          #   - Issues Total > X
          #   - PR Total > 180
          #   - Last year commits > 100
          #   - Total Downloads > 2M
          #   - Total Releases > 55
          #
          # Reference:
          #   - (0.1) Time between first and last PR/Issue is 4+ years
          #   - (0.1) Last Issue or PR creation date within last half of a year
          #   - (0.05 + 0.05) Non-owner PRs > 60%, Issues > 60%
          #   - (0.05 + 0.05) Open PRs < 5%, Issues < 10%
          #   - (0.05 + 0.05) With contributors comments PRs > 12%, Issues > 78%
          #
          #
          # Comunity.
          # Each metric has absolute value and gives 0,1 probability:
          #   - Users creating issues > 375
          #   - Users commenting issues > 500
          #   - Users creating pulls > 90
          #   - Users commenting pulls > 24
          #   - Users contributors > 70
          #   - Users watchers > 50
          #   - Users stargazers > 1000
          #   - Users forks > 150
          #   - Users total > 1200
          #   - Users total without stargazers > 400
          # :first_pr_date_int, :last_pr_date_int,
          # :first_issue_date_int, :last_issue_date_int,
          # :last_release_date_int, :commits_count_since_last_release_count,
          # :pr_active_percent, :issues_active_percent,
          # :watchers_count,
          # :total_downloads, :download_divergence,



          :issues_all_count, :pr_all_count, :total_downloads, :releases_count, :last_year_commits,
          :life_period, :last_changed,

          # :issues_non_owner_percent, :pr_non_owner_percent,
          # :pr_closed_percent, :issues_closed_percent, :pr_with_contrib_comments_percent,
          # :pr_active_percent, :issues_active_percent,
          # :first_pr_date_int, :last_pr_date_int,
          # :first_issue_date_int, :last_issue_date_int,
          # :last_release_date_int, :commits_count_since_last_release_count,
          # :issues_with_contrib_comments_percent,



          :users_creating_issues_count, :users_commenting_issues_count, :users_creating_pr_count,
          :users_commenting_pr_count, :contributors_count, :stargazers_count,
          :watchers_count, :forks_count, :users_involved_count, :users_involved_no_stars_count
        ]

        all_metrics = full_metrics + half_metrics

        agility_total_classifier.each_pair do |ref_class, metrics|
          metrics.each_pair do |metric, values|
            next unless all_metrics.include? metric
            threshold = values[:threshold]
            gain = half_metrics.include?(metric) ? 0.05 : 0.1
            agility_total_results[ref_class] += gain if project.agility.total.send(metric).to_f >= threshold
          end
        end

        agility_quarter_classifier.each_pair do |ref_class, metrics|
          metrics.each_pair do |metric, values|
            next unless all_metrics.include? metric
            threshold = values[:threshold]
            agility_quarter_results[ref_class] += 0.11 if project.agility.quarters.last_year_as_hash[metric].to_f >= threshold
          end
        end

        community_total_classifier.each_pair do |ref_class, metrics|
          metrics.each_pair do |metric, values|
            next unless all_metrics.include? metric
            threshold = values[:threshold]
            community_total_results[ref_class] += 0.11 if project.community.total.send(metric).to_f >= threshold
          end
        end

        community_quarter_classifier.each_pair do |ref_class, metrics|
          metrics.each_pair do |metric, values|
            next unless all_metrics.include? metric
            threshold = values[:threshold]
            community_quarter_results[ref_class] += 0.11 if project.community.quarters.last_year_as_hash[metric].to_f >= threshold
          end
        end

        agility_total_decision = 'ClassE'
        community_total_decision = 'ClassE'
        agility_quarter_decision = 'ClassE'
        community_quarter_decision = 'ClassE'

        agility_total_results.each_pair do |ref_class, gain|
          next if gain <= 0.5
          agility_total_decision = ref_class
          break
        end

        community_total_results.each_pair do |ref_class, gain|
          next if gain <= 0.5
          community_total_decision = ref_class
          break
        end

        agility_quarter_results.each_pair do |ref_class, gain|
          next if gain <= 0.5
          agility_quarter_decision = ref_class
          break
        end

        community_quarter_results.each_pair do |ref_class, gain|
          next if gain <= 0.5
          community_quarter_decision = ref_class
          break
        end

        {
          agility: {
            total: agility_total_decision,
            last_year: agility_quarter_decision
          },
          community: {
            total: community_total_decision,
            last_year: community_quarter_decision
          },
          agility_total_probs: agility_total_results,
          community_total_probs: community_total_results,
          agility_quarter_probs: agility_quarter_results,
          community_quarter_probs: community_quarter_results
        }
      end

      def train
        grouped_projects = train_group
        @agility_total_classifier, @community_total_classifier = {}, {}
        @agility_quarter_classifier, @community_quarter_classifier = {}, {}
        CLASSES.each do |ref_class|
          grouped_projects[ref_class].each do |project|
            [:issues_all_count, :pr_all_count, :total_downloads, :releases_count, :last_year_commits,
             :life_period, :last_changed, :issues_non_owner_percent, :pr_non_owner_percent,
             :pr_closed_percent, :issues_closed_percent, :pr_with_contrib_comments_percent,
             :pr_active_percent, :issues_active_percent,
             :first_pr_date_int, :last_pr_date_int,
             :first_issue_date_int, :last_issue_date_int,
             :last_release_date_int, :commits_count_since_last_release_count,
             :issues_with_contrib_comments_percent].each do |metric|
              next_metric_val = project.agility.total.send(metric).to_f
              ((@agility_total_classifier[ref_class] ||= {})[metric] ||= []) << next_metric_val
            end

            [:issues_closed_percent, :issues_active_percent, :issues_all_count,
             :pr_closed_percent, :pr_active_percent, :pr_all_count,
             :total_downloads, :download_divergence,
             :releases_count, :commits, :delta_downloads].each do |metric|
              next_metric_val = project.agility.quarters.last_year_as_hash[metric].to_f
              ((@agility_quarter_classifier[ref_class] ||= {})[metric] ||= []) << next_metric_val
            end

            [:users_creating_issues_count, :users_commenting_issues_count, :users_creating_pr_count,
             :users_commenting_pr_count, :contributors_count, :stargazers_count,
             :watchers_count,
             :forks_count, :users_involved_count, :users_involved_no_stars_count].each do |metric|
              next_metric_val = project.community.total.send(metric).to_f
              ((@community_total_classifier[ref_class] ||= {})[metric] ||= []) << next_metric_val
              next_metric_val = project.community.quarters.last_year_as_hash[metric].to_f
              ((@community_quarter_classifier[ref_class] ||= {})[metric] ||= []) << next_metric_val
            end

          end
        end

        CLASSES.each_with_index do |ref_class, idx|
          @agility_total_classifier[ref_class].each_pair do |metric, values|
            sibling_class_values = if (idx + 1) < CLASSES.count
                                      @agility_total_classifier[CLASSES[idx+1]][metric]
                                    else
                                      []
                                    end
            all_values = sibling_class_values + values
            @agility_total_classifier[ref_class][metric] = (values.max || 0) and next if all_values.count <= 2
            @agility_total_classifier[ref_class][metric] = (all_values.sum/all_values.count).round(2)
          end

          @agility_quarter_classifier[ref_class].each_pair do |metric, values|
            sibling_class_values = if (idx + 1) < CLASSES.count
                                      @agility_quarter_classifier[CLASSES[idx+1]][metric]
                                    else
                                      []
                                    end
            all_values = sibling_class_values + values
            @agility_quarter_classifier[ref_class][metric] = (values.max || 0) and next if all_values.count <= 2
            @agility_quarter_classifier[ref_class][metric] = (all_values.sum/all_values.count).round(2)
          end

          @community_total_classifier[ref_class].each_pair do |metric, values|
            sibling_class_values = if (idx + 1) < CLASSES.count
                                      @community_total_classifier[CLASSES[idx+1]][metric]
                                    else
                                      []
                                    end
            all_values = sibling_class_values + values
            @community_total_classifier[ref_class][metric] = (values.max || 0) and next if all_values.count <= 2
            @community_total_classifier[ref_class][metric] = (all_values.sum/all_values.count).round(2)
          end

          @community_quarter_classifier[ref_class].each_pair do |metric, values|
            sibling_class_values = if (idx + 1) < CLASSES.count
                                      @community_quarter_classifier[CLASSES[idx+1]][metric]
                                    else
                                      []
                                    end
            all_values = sibling_class_values + values
            @community_quarter_classifier[ref_class][metric] = (values.max || 0) and next if all_values.count <= 2
            @community_quarter_classifier[ref_class][metric] = (all_values.sum/all_values.count).round(2)
          end
        end

        # fix syntetics
        [@agility_total_classifier, @agility_quarter_classifier,
          @community_total_classifier, @community_quarter_classifier].each do |classifier|
          SYNTETIC.each do |synt_metric|
            best_value = classifier.values.map { |metrics| metrics[synt_metric] }.compact.max
            next if best_value.to_f.zero?

            CLASSES.each_with_index do |ref_class, idx|
              classifier[ref_class][synt_metric] = (best_value / (idx + 1).to_f).round(2)
            end
          end
        end

        # replace values with ranges
        CLASSES.each_with_index do |ref_class, idx|
          [@agility_total_classifier, @agility_quarter_classifier,
           @community_total_classifier, @community_quarter_classifier].each do |classifier|
            classifier[ref_class].each_pair do |metric, value|
              higher_class_value = if (idx - 1) >= 0
                                     classifier[CLASSES[idx-1]][metric][:threshold]
                                   else
                                     :none
                                   end
              start_value = if higher_class_value == :none
                              value
                            elsif idx == CLASSES.count - 1
                              classifier[CLASSES.first][metric][:threshold] > value ? -Float::INFINITY : Float::INFINITY
                            else
                              value
                            end

              end_value = if higher_class_value == :none
                            classifier[CLASSES.last][metric] < value ? Float::INFINITY : -Float::INFINITY
                          else
                            higher_class_value
                          end
              classifier[ref_class][metric] = {
                threshold: value,
                range: start_value...end_value
              }
            end
          end
        end
      end
    end
  end
end
