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
  task :collect_referencies do
    puts 'Run collecting process'
    time = Benchmark.realtime do
      ::Ossert.init
      ::Project.db.transaction do
        Ossert::Project.cleanup_referencies!
        reference_projects = Ossert::Reference.prepare_projects!
        Ossert::Reference.process_references(reference_projects)
      end
    end

    puts "Collecting process finished in #{time.round(3)} sec."
  end

  desc 'Invoke data updates for stale projects'
  task :refresh_data do
    require './config/sidekiq.rb'
    Ossert::Workers::RefreshFetch.perform_async
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
