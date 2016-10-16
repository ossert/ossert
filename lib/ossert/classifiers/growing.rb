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

        def config
          @config ||= Settings['classifiers']['growth']
        end

        def syntetics
          @syntetics ||= config['syntetics']
        end

        def reversed
          @reversed ||= config['reversed']
        end
      end

      def initialize(train_group)
        @train_group = train_group

        (self.class.all ||= []) << self
      end

      attr_reader :train_group
      attr_reader :agility_total_classifier, :community_total_classifier,
                  :agility_last_year_classifier, :community_last_year_classifier

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
        agility_total, agility_quarter, community_total, community_quarter = [
          agility_total_classifier, agility_last_year_classifier,
          community_total_classifier, community_last_year_classifier
        ].map do |classifier|
          classifier.each_with_object({}) do |(ref_class, metrics), res|
            metrics.each do |metric, value|
              (res[metric] ||= {})[ref_class] = value
            end
          end
        end
        {
          agility_total: agility_total,
          agility_quarter: agility_quarter,
          agility_year: agility_quarter,
          community_total: community_total,
          community_quarter: community_quarter,
          community_year: community_quarter
        }
      end

      # FIXME: Refactor this with config and maybe divide by classes Teacher and Evaluation
      def check(project)
        popularity_rates = CLASSES.each_with_object({}) { |klass, res| res[klass] = 0.0.to_d }
        maintenance_rates = agility_total_results.dup
        maturity_rates = agility_total_results.dup

        popularity_metrics = config['metrics']['popularity']
        maintenance_metrics = config['metrics']['maintenance']
        maturity_metrics = config['metrics']['maturity']

        # populariity
        max_gain = popularity_metrics['last_year'].values.sum + popularity_metrics['total'].values.sum

        total_data = project.community.total
        community_total_classifier.each_pair do |grade, metrics|
          popularity_metrics['total'].each_pair do |metric, weight|
            gain = weight.to_d / max_gain.to_d
            popularity_rates[grade] += gain if range.cover? total_data.send(metric).to_f
          end
        end

        rate = (->(rates, metrics, data, classifiers) {
          classifier.each_pair do |grade, qualified_metrics|
            metrics.each_pair do |metric, checks|
              range = qualified_metrics[metric][:range]
              rates[grade] += (weight.to_d / max_gain.to_d) if range.cover? data.send(metric).to_f
            end
          end
        })
        # Popularity
        rate.(
          popularity_rates,
          popularity_metrics['last_year'],
          project.community.quarters.last_year_as_hash,
          community_last_year_classifier
        )
        rate.(
          popularity_rates,
          popularity_metrics['total'],
          project.community.total,
          community_total_classifier
        )

        # Maintenance
        rate.(
          maintenance_rates,
          maintenance_metrics['last_year'],
          project.agility.quarters.last_year_as_hash,
          agility_last_year_classifier
        )
        rate.(
          maintenance_rates,
          maintenance_metrics['total'],
          project.agility.total,
          agility_total_classifier
        )

        # Maturity
        rate.(
          maturity_rates,
          maturity_metrics['last_year'],
          project.agility.quarters.last_year_as_hash,
          agility_last_year_classifier
        )
        rate.(
          maturity_rates,
          maturity_metrics['last_year'],
          project.agility.quarters.last_year_as_hash,
          community_last_year_classifier
        )
        rate.(
          maturity_rates,
          maturity_metrics['total'],
          project.agility.total,
          agility_total_classifier
        )
        rate.(
          maturity_rates,
          maturity_metrics['total'],
          project.agility.total,
          community_total_classifier
        )

        {
          popularity: rate(popularity_rates),
          maintenance: rate(maintenance_rates),
          maturity: rate(maturity_rates)
        }
      end

      def rate(classifier_results)
        grade = 'ClassE'
        classifier_results.each_pair do |reference_klass, gain|
          next if gain <= 0.5
          grade = reference_klass
          break
        end
        grade
      end

      def train
        grouped_projects = train_group
        @agility_total_classifier, @community_total_classifier = {}, {}
        @agility_last_year_classifier, @community_last_year_classifier = {}, {}

        process_collection(grouped_projects)

        process_aggregation

        # fix syntetics
        process_syntetics

        # replace values with ranges
        process_values_to_ranges

        # fix reversed
        process_reversed
      end

      def process_collection(grouped_projects)
        CLASSES.each do |ref_class|
          grouped_projects[ref_class].each do |project|
            [:issues_all_count, :pr_all_count, :releases_count, :last_year_commits,
             :life_period, :last_changed, :issues_non_owner_percent, :pr_non_owner_percent,
             :pr_closed_percent, :issues_closed_percent, :pr_with_contrib_comments_percent,
             :pr_active_percent, :issues_active_percent,
             :issues_processed_in_avg, :pr_processed_in_avg,
             :first_pr_date_int, :last_pr_date_int,
             :first_issue_date_int, :last_issue_date_int,
             :last_release_date_int, :commits_count_since_last_release_count,
             :stale_branches_count,
             :issues_with_contrib_comments_percent].each do |metric|
              next_metric_val = project.agility.total.send(metric).to_f
              ((@agility_total_classifier[ref_class] ||= {})[metric] ||= []) << next_metric_val
            end

            [:issues_closed_percent, :issues_active_percent, :issues_all_count, :issues_actual_count,
             :pr_closed_percent, :pr_active_percent, :pr_all_count, :pr_actual_count,
             :issues_processed_in_avg, :pr_processed_in_avg,
             :releases_count, :commits].each do |metric|
              next_metric_val = project.agility.quarters.last_year_as_hash[metric].to_f
              ((@agility_last_year_classifier[ref_class] ||= {})[metric] ||= []) << next_metric_val
            end

            [:users_creating_issues_count, :users_commenting_issues_count, :users_creating_pr_count,
             :users_commenting_pr_count, :contributors_count, :stargazers_count,
             :watchers_count, :total_downloads,
             :forks_count, :users_involved_count, :users_involved_no_stars_count].each do |metric|
              next_metric_val = project.community.total.send(metric).to_f
              ((@community_total_classifier[ref_class] ||= {})[metric] ||= []) << next_metric_val
            end

            [:users_creating_issues_count, :users_commenting_issues_count, :users_creating_pr_count,
             :users_commenting_pr_count, :contributors_count, :stargazers_count,
             :watchers_count,
             :forks_count, :users_involved_count, :users_involved_no_stars_count,
             :total_downloads, :delta_downloads, :download_divergence].each do |metric|
              next_metric_val = project.community.quarters.last_year_as_hash[metric].to_f
              ((@community_last_year_classifier[ref_class] ||= {})[metric] ||= []) << next_metric_val
            end
          end
        end
      end

      def process_aggregation
        CLASSES.each_with_index do |ref_class, idx|
          [@agility_total_classifier, @agility_last_year_classifier,
           @community_total_classifier, @community_last_year_classifier].each do |classifier|
            classifier[ref_class].each_pair do |metric, values|
              sibling_class_values = if (idx + 1) < CLASSES.count
                                        classifier[CLASSES[idx+1]][metric]
                                      else
                                        []
                                      end
              all_values = sibling_class_values + values
              classifier[ref_class][metric] = (values.max || 0) and next if all_values.count <= 2
              classifier[ref_class][metric] = (all_values.sum/all_values.count).round(2)
            end
          end
        end
      end

      def process_syntetics
        [@agility_total_classifier, @agility_last_year_classifier,
          @community_total_classifier, @community_last_year_classifier].each do |classifier|
          self.class.syntetics.each do |synt_metric|
            synt_metric, best_value = synt_metric.first if synt_metric.is_a? Hash
            real_values = classifier.values.map { |metrics| metrics[synt_metric] }.compact
            best_value ||= real_values.max
            next if real_values.empty?

            growth = (best_value / CLASSES.count.to_f).round(2)
            CLASSES.reverse.each_with_index do |ref_class, idx|
              classifier[ref_class][synt_metric] = (growth * (idx + 1)).round(2)
            end
          end
        end
      end

      def process_values_to_ranges
        CLASSES.each_with_index do |ref_class, idx|
          [@agility_total_classifier, @agility_last_year_classifier,
           @community_total_classifier, @community_last_year_classifier].each do |classifier|
            classifier[ref_class].each_pair do |metric, value|
              reversed = self.class.reversed.include? metric
              any_value_idx = reversed ? 0 : CLASSES.count - 1

              if idx == any_value_idx
                start_value, end_value = -Float::INFINITY, Float::INFINITY
              else
                start_value = reversed ? -Float::INFINITY : value
                end_value = reversed ? value : Float::INFINITY
              end

              classifier[ref_class][metric] = {
                threshold: value,
                range: start_value...end_value
              }
            end
          end
        end
      end

      def process_reversed
        [@agility_total_classifier, @agility_last_year_classifier,
          @community_total_classifier, @community_last_year_classifier].each do |classifier|
          self.class.reversed.each do |reversed_metric|
            CLASSES.first((CLASSES.count / 2.0).ceil).each_with_index do |ref_class, idx|
              next unless classifier[ref_class][reversed_metric].present?
              previous_value = classifier[reversed(ref_class)][reversed_metric]
              classifier[reversed(ref_class)][reversed_metric] = classifier[ref_class][reversed_metric]
              classifier[ref_class][reversed_metric] = previous_value
            end
          end
        end
      end
    end
  end
end
