# frozen_string_literal: true
module Ossert
  module Reference
    def prepare_projects!
      references = %w(A B C D E).map { |e| Kernel.const_get("Ossert::Reference::Class#{e}").new }
      references.each(&:prepare_projects!)
      references
    end
    module_function :prepare_projects!

    def process_references(references)
      require './config/sidekiq'
      Array(references).each do |reference|
        reference.project_names.each_with_object(reference.class.name.demodulize) do |project_name, klass|
          if Ossert::Project.exist?(project_name)
            project = Ossert::Project.load_by_name(project_name)
            project.reference = klass
            project.dump
          else
            Ossert::Workers::Fetch.perform_async(project_name, klass)
          end
        end
      end
    end
    module_function :process_references

    class Base
      CLASSES = %w(ClassA ClassB ClassC ClassD ClassE).freeze

      attr_reader :representative, :pages, :project_names

      def initialize(representative, pages)
        @representative = representative
        @pages = pages
        @project_names = Set.new
        # 20 each page, total 5907 pages
      end

      PER_PAGE = 20

      def prepare_projects!
        puts "Processing #{self.class.name}"
        all_pages = pages.to_a.shuffle
        all_projects = {}
        (representative / PER_PAGE).times do
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
        super(50, 1..10)
      end
    end

    class ClassB < Base
      def initialize
        super(50, 11..100)
      end
    end

    class ClassC < Base
      def initialize
        super(50, 101..250)
      end
    end

    class ClassD < Base
      def initialize
        super(50, 251..500)
      end
    end

    class ClassE < Base
      def initialize
        super(50, 501..2500)
      end
    end
  end
end
