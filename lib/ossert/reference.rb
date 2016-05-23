require 'graphr'
require 'decisiontree'

module Ossert
  module Reference
    class Base
      CLASSES = %w(ClassA ClassB ClassC ClassD ClassE)
      CLASS_DOWNLOADS_THRESHOLD = [2_000_000, 750_000, 150_000, 10_000, 0]
      CLASS_LAST_YEAR_COMMIT_THRESHOLD = [100, 22, 14, 4, 0]
      CLASS_CONTRIBUTORS_THRESHOLD = [70, 28, 12, 3, 0]
      CLASS_LIFE_PERIOD_THRESHOLD = [3.year, 2.year, 1.year, 6.month, 0]
      #   - Users contributors > 70
      #   - Users contributors > 28
      #   - Users contributors > 12
      #   - Users contributors > 3
      # CLASS_RELEASES_THRESHOLD = [55, 24, 12, 5, 0]

      attr_reader :total, :representative, :pages, :project_names

      def initialize(representative, total, pages)
        @representative = representative
        @total = total
        @pages = pages
        @project_names = Set.new
        (Base.refs ||= []) << self
        # 20 each page, total 5907 pages
      end

      def prepare_projects!
        all_pages = pages.to_a.shuffle
        all_projects = Hash.new
        representative.times do
          current_page = all_pages.pop
          Fetch::BestgemsTotalStat.process_page(current_page) do |rank, downloads, name|
            all_projects[name] = {rank: rank, downloads: downloads}
          end
        end

        # @project_names.merge all_projects.keys.shuffle.first(representative)
        @project_names.merge Hash[all_projects.sort_by {|_, info| info[:downloads]}].keys.last(representative)
      end

      class << self
        attr_accessor :refs

        # FIXME: Use normal backend, such as Postgres
        def load
          @refs = %w(A B C D E).map { |e| "Ossert::Reference::Class#{e}".constantize.new.load }
        end

        def dump
          @refs.each { |ref| ref.dump }
        end

        attr_reader :agility_total_classifier, :community_total_classifier,
                    :agility_quarter_classifier, :community_quarter_classifier

        def growing_classifier_ready?
          agility_total_classifier.keys == CLASSES && community_total_classifier.keys == CLASSES
        end

        def check_against_growing_classifier(project)
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

        def train_growing_classifier
          grouped_projects = Project.projects_by_reference
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

        attr_reader :agility_total_dec_tree, :agility_total_dec_tree, :agility_quarters_dec_tree,
                    :agility_quarters_dec_tree, :community_total_dec_tree, :community_total_dec_tree,
                    :community_quarters_dec_tree, :community_quarters_dec_tree

        def decision_tree_ready?
          agility_total_dec_tree.presence &&
          agility_quarters_dec_tree.presence &&
          community_total_dec_tree.presence &&
          community_quarters_dec_tree
        end
        def train_descision_tree
          grouped_projects = Project.projects_by_reference
          agility_total_attributes = AgilityQuarterStat.metrics
          agility_quarters_attributes = AgilityTotalStat.metrics
          community_total_attributes = CommunityTotalStat.metrics
          community_quarters_attributes = CommunityQuarterStat.metrics
          agility_total_data, community_total_data, agility_last_year_data, community_last_year_data = [], [], [], []

          CLASSES.each_with_index do |ref_class, i|
            grouped_projects[ref_class].each do |project|
              agility_total_data << (project.agility.total.metric_values << ref_class)
              community_total_data << (project.community.total.metric_values << ref_class)
              if (last_year_data = project.agility.quarters.last_year_data).present?
                agility_last_year_data << (project.agility.quarters.last_year_data << ref_class)
              end
              if (last_year_data = project.community.quarters.last_year_data).present?
                community_last_year_data << (project.community.quarters.last_year_data << ref_class)
              end
            end
          end

          @agility_total_dec_tree = DecisionTree::ID3Tree.new(
            agility_total_attributes, agility_total_data, 'ClassE', :continuous
          )
          @agility_total_dec_tree.train
          @agility_quarters_dec_tree = DecisionTree::ID3Tree.new(
            agility_quarters_attributes, agility_last_year_data, 'ClassE', :continuous
          )
          @agility_quarters_dec_tree.train
          @community_total_dec_tree = DecisionTree::ID3Tree.new(
            community_total_attributes, community_total_data, 'ClassE', :continuous
          )
          @community_total_dec_tree.train
          @community_quarters_dec_tree = DecisionTree::ID3Tree.new(
            community_quarters_attributes, community_last_year_data, 'ClassE', :continuous
          )
          @community_quarters_dec_tree.train
        end

        def prepare_projects!
          %w(A B C D E).map { |e| "Ossert::Reference::Class#{e}".constantize.new.prepare_projects! }
        end

        def collect_stats_for_refs!(force = false)
          existing_projects = Set.new(Project.projects.map { |p| p.name })
          threads = []
          puts "==== COLLECTING REFERENCE PROJECTS ===="
          @refs.in_groups_of(3, false).each do |_batch|
            threads << Thread.new(_batch) do |batch|
              batch.each do |reference|
                proj_class = reference.class.name.demodulize
                reference.project_names.each do |project_name|
                  puts "#{proj_class} reference project: '#{project_name}'"
                  if !force && existing_projects.include?(project_name)
                    puts "Exists. Skipping"
                    next
                  end

                  begin
                    Ossert::Fetch.all Ossert::Project.new(project_name, nil, project_name, proj_class)
                  rescue ArgumentError
                    puts "Fetching Failed for '#{project_name}'"
                  end
                  sleep(5)
                end
              end
            end
          end
          threads.each {|thr| thr.join }
          puts "Done with reference projects."
        end
      end

      # FIXME: Use normal backend, such as Postgres
      def load
        if File.exists?("data/#{self.class.name}.json")
          @project_names = Oj.load File.read("data/#{self.class.name}.json")
        end
        self
      end

      def dump
        existance_backup("data/#{self.class.name}.json")
        File.open("data/#{self.class.name}.json","w") do |f|
          f.write(Oj.dump(project_names))
        end
      end

      def existance_backup(filename)
        return unless File.exists?(filename)
        FileUtils.cp(filename, "#{filename}.#{Time.now.strftime('%d%m%Y-%H%M%S.%L')}")
      end
    end

    class ClassA < Base
      def initialize
        super(25, 500, 1..25)
        # super(5, 500, 1..25)
      end

      # Projects should have those metric values
      #
      # Agility.
      # Each Absolute metric gives 0.1 probability of Class A qualification
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
      #
    end

    class ClassB < Base
      def initialize
        super(25, 500, 26..50)
        # super(10, 500, 26..50)
      end

      # Projects should have those metric values
      #
      # Agility.
      # Each Absolute metric gives 0.1 probability of Class B qualification
      # Absolute:
      #   - Issues Total > X
      #   - PR Total > 24
      #   - Last year commits > 22
      #   - Total Downloads > 750K
      #   - Total Releases > 24
      #
      # Reference:
      #   - (0.1) Time between first and last PR/Issue is 3+ years
      #   - (0.1) Last Issue or PR creation date within last year
      #   - (0.05 + 0.05) Non-owner PRs > 50%, Issues > 50%
      #   - (0.05 + 0.05) Open PRs < 25%, Issues < 28%
      #   - (0.05 + 0.05) With contributors comments PRs > 10%, Issues > 58%
      #
      #
      # Comunity.
      # Each metric has absolute value and gives 0,1 probability:
      #   - Users creating issues > 42
      #   - Users commenting issues > 42
      #   - Users creating pulls > 21
      #   - Users commenting pulls > 3 ???
      #   - Users contributors > 28
      #   - Users watchers > 24
      #   - Users stargazers > 180
      #   - Users forks > 40
      #   - Users total > 300
      #   - Users total without stargazers > 60
      #
    end

    class ClassC < Base
      def initialize
        super(100, 10000, 51..550)
        # super(10, 10000, 51..550)
      end

      # Projects should have those metric values
      #
      # Agility.
      # Each Absolute metric gives 0.1 probability of Class C qualification
      # Absolute:
      #   - Issues Total > X
      #   - PR Total > 18
      #   - Last year commits > 14
      #   - Total Downloads > 150K
      #   - Total Releases > 12
      #
      # Reference:
      #   - (0.1) Time between first and last PR/Issue is 2+ years
      #   - (0.1) Last Issue or PR creation date within last 1.5 years
      #   - (0.05 + 0.05) Non-owner PRs > 30%, Issues > 28%
      #   - (0.05 + 0.05) Open PRs < 45%, Issues < 46%
      #   - (0.05 + 0.05) With contributors comments PRs > 10%, Issues > 58%
      #
      #
      # Comunity.
      # Each metric has absolute value and gives 0,1 probability:
      #   - Users creating issues > 23
      #   - Users commenting issues > 24
      #   - Users creating pulls > 21
      #   - Users commenting pulls > 4
      #   - Users contributors > 12
      #   - Users watchers > 7
      #   - Users stargazers > 120
      #   - Users forks > 25
      #   - Users total > 200
      #   - Users total without stargazers > 49
      #
    end

    class ClassD < Base
      def initialize
        super(100, 50000, 551..2500)
        # super(10, 50000, 551..2500)
      end

      # Projects should have those metric values
      #
      # Agility.
      # Each Absolute metric gives 0.1 probability of Class D qualification
      # Absolute:
      #   - Issues Total > X
      #   - PR Total > 5
      #   - Last year commits > 4
      #   - Total Downloads > 10K
      #   - Total Releases > 5
      #
      # Reference:
      #   - (0.1) Time between first and last PR/Issue is 1+ years
      #   - (0.1) Last Issue or PR creation date within last 2 years
      #   - (0.05 + 0.05) Non-owner PRs > 15%, Issues > 14%
      #   - (0.05 + 0.05) Open PRs < 65%, Issues < 66%
      #   - (0.05 + 0.05) With contributors comments PRs > 4%, Issues > 19%
      #
      #
      # Comunity.
      # Each metric has absolute value and gives 0,1 probability:
      #   - Users creating issues > 4
      #   - Users commenting issues > 4
      #   - Users creating pulls > 4
      #   - Users commenting pulls > 0
      #   - Users contributors > 3
      #   - Users watchers > 3
      #   - Users stargazers > 8
      #   - Users forks > 7
      #   - Users total > 28
      #   - Users total without stargazers > 6
      #
    end

    class ClassE < Base
      def initialize
        super(100, 50000, 2501..5000)
        # super(10, 50000, 2501..5000)
      end

      # Projects should have those metric values
      #
      # Agility.
      # Each Absolute metric gives 0.1 probability of Class E qualification
      # Absolute:
      #   - Issues Total > X
      #   - PR Total >= 0
      #   - Last year commits >= 0
      #   - Total Downloads >= 0
      #   - Total Releases >= 0
      #
      # Reference:
      #   - (0.1) Time between first and last PR/Issue is within 1 year
      #   - (0.1) Last Issue or PR creation date within last 4 years
      #   - (0.05 + 0.05) Non-owner PRs > 0%, Issues > 0%
      #   - (0.05 + 0.05) Open PRs < 100%, Issues < 100%
      #   - (0.05 + 0.05) With contributors comments PRs > 0%, Issues > 0%
      #
      #
      # Comunity.
      # Each metric has absolute value and gives 0,1 probability:
      #   - Users creating issues > 0
      #   - Users commenting issues > 0
      #   - Users creating pulls > 0
      #   - Users commenting pulls > 0
      #   - Users contributors > 0
      #   - Users watchers > 0
      #   - Users stargazers > 0
      #   - Users forks > 0
      #   - Users total > 0
      #   - Users total without stargazers > 0
      #
    end
  end
end
