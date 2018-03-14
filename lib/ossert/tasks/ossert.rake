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

  namespace :twitter do
    desc 'Fetches twitter metrics for top 100 random projects'
    task :enqueue_jobs do
      require './config/sidekiq.rb'
      ::Ossert.init

      Ossert::Project.random_top(100).each do |project|
        Ossert::Workers::FetchTwitter.perform_async(project.name)
      end
    end
  end
 
  namespace :refresh do
    desc 'Refresh StackOverflow data for all projects'
    task :stackoverflow do
      require './config/sidekiq.rb'
      Ossert::Workers::PartialRefreshFetch.perform_async(:StackOverflow)
    end

    desc 'Refresh Rubygems data for all projects'
    task :rubygems do
      require './config/sidekiq.rb'
      Ossert::Workers::PartialRefreshFetch.perform_async(:Rubygems)
    end

    desc 'Refresh GitHub data for all projects'
    task :github do
      require './config/sidekiq.rb'
      Ossert::Workers::PartialRefreshFetch.perform_async(:GitHub)
    end

    desc 'Refresh Bestgems data for all projects'
    task :bestgems do
      require './config/sidekiq.rb'
      Ossert::Workers::PartialRefreshFetch.perform_async(:Bestgems)
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
    if NameException.find(args.name)
      exceptions_repo.update(
        args.name,
        name: args.name,
        github_name: args.github_name
      )
    else
      NameException.create(
        name: args.name,
        github_name: args.github_name
      )
    end
    puts "Exception '#{args.name}' => '#{args.github_name}' saved!"
  end
end
