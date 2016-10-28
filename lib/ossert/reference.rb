# frozen_string_literal: true
module Ossert
  module Reference
    def prepare_projects!
      references = %w(A B C D E).map { |e| Kernel.const_get("Ossert::Reference::Class#{e}").new }
      references.each(&:prepare_projects!)
      references
    end
    module_function :prepare_projects!

    # Most resource consuming method
    def collect_stats_for_refs!(refs)
      threads = []
      puts '==== COLLECTING REFERENCE PROJECTS ===='
      refs.in_groups_of(3, false).each do |thread_batch|
        threads << Thread.new(thread_batch) do |batch|
          process_references batch
        end
      end
      threads.each(&:join)
      puts 'Done with reference projects.'
    end
    module_function :collect_stats_for_refs!

    def process_references(references)
      Array(references).each do |reference|
        reference.project_names.each_with_object(reference.class.name.demodulize) do |project_name, klass|
          Ossert::Project.fetch_all(project_name.dup, klass)
          sleep(5) && GC.start
        end
      end
    end

    class Base
      CLASSES = %w(ClassA ClassB ClassC ClassD ClassE).freeze

      attr_reader :total, :representative, :pages, :project_names

      def initialize(representative, total, pages)
        @representative = representative
        @total = total
        @pages = pages
        @project_names = Set.new
        # 20 each page, total 5907 pages
      end

      def prepare_projects!
        all_pages = pages.to_a.shuffle
        all_projects = {}
        representative.times do
          current_page = all_pages.pop
          Fetch::BestgemsDailyStat.process_page(current_page) do |rank, downloads, name|
            all_projects[name] = { rank: rank, downloads: downloads }
          end
        end

        # @project_names.merge all_projects.keys.shuffle.first(representative)
        @project_names.merge all_projects.sort_by { |_, info| info[:downloads] }.to_h.keys.last(representative)
      end
    end

    class ClassA < Base
      def initialize
        super(25, 500, 1..25)
        # super(5, 500, 1..25)
      end
    end

    class ClassB < Base
      def initialize
        super(25, 500, 26..50)
      end
    end

    class ClassC < Base
      def initialize
        super(100, 10_000, 51..550)
      end
    end

    class ClassD < Base
      def initialize
        super(100, 50_000, 551..2500)
      end
    end

    class ClassE < Base
      def initialize
        super(100, 50_000, 2501..5000)
      end
    end
  end
end
