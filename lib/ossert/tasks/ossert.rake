# frozen_string_literal: true
namespace :ossert do
  namespace :cache do
    desc 'Reset data cache'
    task :reset do
      ::Ossert.init
      ::Classifier.dataset.delete
      Ossert::Classifiers::Growing.new.train
      true
    end
  end

  desc 'Collect reference projects'
  task collect: ['db:dump'] do
    begin
      puts 'Run collecting process'
      time = Benchmark.realtime do
        Ossert::Project.cleanup_referencies!
        reference_projects = Ossert::Reference.prepare_projects!
        Ossert::Reference.collect_stats_for_refs!(reference_projects)
      end

      puts "Collecting process finished in #{time.round(3)} sec."
    rescue
      Rake::Task['db:restore:last'].invoke
    end
  end

  desc 'Add or replace project name exception'
  task :exception, [:name, :github_name] do |_, args|
    raise 'Arguments name and GitHub name expected' unless args.name.present? && args.github_name.present?
    exceptions_repo = ExceptionsRepo.new(Ossert.rom)
    if exceptions_repo[args.name]
      exceptions_repo.update(
        args.name,
        name: args.name,
        github_name: args.github_name
      )
    else
      exceptions_repo.create(
        name: args.name,
        github_name: args.github_name
      )
    end
    puts "Exception '#{args.name}' => '#{args.github_name}' saved!"
  end
end
