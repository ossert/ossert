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
    desc 'Schedules twitter fetch jobs for nearest 24 hour'
    task :schedule, [:dry_run] do
      require './config/sidekiq.rb'
      ::Ossert.init

      SCHEDULE_PERIOD = 24.hours

      dry_run = ENV.fetch('DRY_RUN', false)
      puts 'DRY RUN' if dry_run

      dataset = ::Project
                .dataset
                .where(Sequel.lit('github_name NOT IN (?, ?)', Ossert::NO_GITHUB_NAME, Ossert::NOT_FOUND_GITHUB_NAME))
                .select(:name)

      projects_count = dataset.count

      scheduler = Ossert::Twitter::Scheduler.new

      tokens_count = Ossert::Twitter::Credentials.access_tokens.count
      per_token = scheduler.capacity_per_token(SCHEDULE_PERIOD)
      total_capacity = tokens_count * per_token
 
      puts "Schedule #{total_capacity} of #{projects_count} (limited with capacity #{total_capacity})"
      if dry_run
        if projects_count > total_capacity
          lacking_accounts_count = (projects_count - total_capacity) / per_token
          abort("You need to add #{lacking_accounts_count} more twitter account(s)")
        end
      else
        projects_to_schedule = dataset
          .limit(total_capacity)
          .order(:reference)
          .use_cursor
        scheduler.call(projects_to_schedule)
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
