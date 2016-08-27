module Ossert
  module Reference
    def prepare_projects!
      %w(A B C D E).map { |e| "Ossert::Reference::Class#{e}".constantize.new.prepare_projects! }
    end
    module_function :prepare_projects!

    def collect_stats_for_refs!(refs, force = false)
      existing_projects = Set.new(Project.projects.map { |p| p.name })
      threads = []
      puts "==== COLLECTING REFERENCE PROJECTS ===="
      refs.in_groups_of(3, false).each do |_batch|
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
    module_function :collect_stats_for_refs!

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
      end

      include Ossert::Saveable

      def read
        @project_names
      end

      def assign(saved_data)
        @project_names = saved_data
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
