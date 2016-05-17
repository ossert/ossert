module Ossert
  module Reference
    class Base
      CLASSES = %w(ClassA ClassB ClassC ClassD ClassE)
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

        @project_names.merge all_projects.keys.shuffle.first(representative)
      end


      class << self
        attr_accessor :refs
        def load
          @refs = %w(A B C D E).map { |e| "Ossert::Reference::Class#{e}".constantize.new.load }
        end

        def dump
          @refs.each { |ref| ref.dump }
        end

        def prepare_projects!
          %w(A B C D E).map { |e| "Ossert::Reference::Class#{e}".constantize.new.prepare_projects! }
        end

        def collect_stats_for_refs!(force = false)
          existing_projects = Project.projects.map { |p| p.name }
          puts "==== COLLECTING REFERENCE PROJECTS ===="
          @refs.each_with_index do |reference, idx|
            reference.project_names.each do |project_name|
              puts "#{CLASSES[idx]} reference project: '#{project_name}'"
              if !force && existing_projects.include?(project_name)
                puts "Exists. Skipping"
                next
              end

              begin
                Ossert::Fetch.all Ossert::Project.new(project_name, nil, project_name, CLASSES[idx])
              rescue ArgumentError
                puts "Fetching Failed for '#{project_name}'"
              end
              sleep(5)
            end
          end
          puts "Done with reference projects."
        end
      end

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
      #   - PR Total > 180 (100) ???
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
    end
  end
end
