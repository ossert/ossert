namespace :ossert do
  desc 'Collect reference projects'
  task :collect, [:size] do |t, args|
    Rake::Task["db:dump"].invoke

    # run collect...
    reference_projects = Ossert::Reference.prepare_projects!
    Ossert::Reference.collect_stats_for_refs!(reference_projects)

    Ossert::Project.dump
  end

  desc 'Analyze reference projects'
  task :analyze do |t, args|

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
