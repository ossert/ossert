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
        attr_reader :refs
        def load
          @refs = %w(A B C D E).map { |e| "Ossert::Reference::Class#{e}".constantize.new.load }
        end

        def collect_stats_for_refs!
          puts "==== COLLECTING REFERENCE PROJECTS ===="
          @refs.each_with_index do |class_projects, idx|
            class_projects.each do |project_name|
              puts "#{CLASSES[idx]} reference project: '#{project_name}'"
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
        # super(25, 500, 1..25)
        super(5, 500, 1..25)
      end
    end

    class ClassB < Base
      def initialize
        # super(25, 500, 26..50)
        super(10, 500, 26..50)
      end
    end

    class ClassC < Base
      def initialize
        # super(100, 10000, 51..550)
        super(10, 10000, 51..550)
      end
    end

    class ClassD < Base
      def initialize
        # super(100, 50000, 551..2500)
        super(10, 50000, 551..2500)
      end
    end

    class ClassE < Base
      def initialize
        # super(100, 50000, 2501..5000)
        super(10, 50000, 2501..5000)
      end
    end
  end
end
