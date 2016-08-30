namespace :ossert do
  desc 'Collect reference projects'
  task :collect => ['db:dump'] do |t, args|
    puts "Run collecting process"
    time = Benchmark.realtime do
      Ossert::Project.cleanup_referencies!
      reference_projects = Ossert::Reference.prepare_projects!
      Ossert::Reference.collect_stats_for_refs!(reference_projects, true)
    end

    puts "Collecting process finished in #{time.round(3)} sec."

    Ossert::Project.dump
    # Rake::Task["db:dump"].invoke
  end
  # desc "Run migrations"
  # task :migrate, [:version] do |t, args|
  #   require "sequel"
  #   Sequel.extension :migration
  #   db = Sequel.connect(ENV.fetch("DATABASE_URL"))
  #   if args[:version]
  #     puts "Migrating to version #{args[:version]}"
  #     Sequel::Migrator.run(db, "db/migrations", target: args[:version].to_i)
  #   else
  #     puts "Migrating to latest"
  #     Sequel::Migrator.run(db, "db/migrations")
  #   end
  # end
end
