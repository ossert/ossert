module Ossert
  module Classifiers
    class Growing
      CLASSES = %w(ClassA ClassB ClassC ClassD ClassE)

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

      def check(project)
        agility_total_results = CLASSES.each_with_object({}) { |klass, res| res[klass] = 0.0 }
        community_total_results = agility_total_results.dup
        agility_quarter_results = agility_total_results.dup
        community_quarter_results = agility_total_results.dup

        half_metrics = [:issues_non_owner_percent, :pr_non_owner_percent,
                        :pr_closed_percent, :issues_closed_percent, :pr_with_contrib_comments_percent,
                        :issues_with_contrib_comments_percent]
        agility_total_classifier.each_pair do |ref_class, metrics|
          metrics.each_pair do |metric, value|
            gain = half_metrics.include?(metric) ? 0.05 : 0.1
            agility_total_results[ref_class] += gain if project.agility.total.send(metric).to_f >= value
          end
        end

        agility_quarter_classifier.each_pair do |ref_class, metrics|
          metrics.each_pair do |metric, value|
            agility_quarter_results[ref_class] += 0.11 if project.agility.quarters.last_year_as_hash[metric].to_f >= value
          end
        end

        community_total_classifier.each_pair do |ref_class, metrics|
          metrics.each_pair do |metric, value|
            community_total_results[ref_class] += 0.11 if project.community.total.send(metric).to_f >= value
          end
        end

        community_quarter_classifier.each_pair do |ref_class, metrics|
          metrics.each_pair do |metric, value|
            community_quarter_results[ref_class] += 0.11 if project.community.quarters.last_year_as_hash[metric].to_f >= value
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
            [:issues_total_count, :pr_total_count, :total_downloads, :releases_count, :last_year_commits,
             :life_period, :last_changed, :issues_non_owner_percent, :pr_non_owner_percent,
             :pr_closed_percent, :issues_closed_percent, :pr_with_contrib_comments_percent,
             :issues_with_contrib_comments_percent].each do |metric|
              next_metric_val = project.agility.total.send(metric).to_f
              ((@agility_total_classifier[ref_class] ||= {})[metric] ||= []) << next_metric_val
            end

            [:issues_closed_count, :issues_open_count, :issues_total_count,
             :pr_closed_count, :pr_open_count, :pr_total_count,
             :releases_count, :commits, :delta_downloads].each do |metric|
              next_metric_val = project.agility.quarters.last_year_as_hash[metric].to_f
              ((@agility_quarter_classifier[ref_class] ||= {})[metric] ||= []) << next_metric_val
            end

            [:users_creating_issues_count, :users_commenting_issues_count, :users_creating_pr_count,
             :users_commenting_pr_count, :contributors_count, :stargazers_count,
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
      end
    end
  end
end
