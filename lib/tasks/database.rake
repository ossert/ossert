namespace :db do
  task :load_config do
    $rom_conf = ROM::Configuration.new(:sql, ENV.fetch("DATABASE_URL"))
  end

  desc 'Create the database, load the schema, and initialize with the seed data (use db:reset to also drop the db first)'
  task :setup => ['db:schema:load', :seed]

  namespace :schema do
    desc 'Create a db/schema.rb file that can be portably used against any DB supported by AR'
    task :dump => [:environment, :load_config] do
      # require 'active_record/schema_dumper'
      # filename = ENV['SCHEMA']
      # File.open(filename, "w:utf-8") do |file|
      #   ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
      # end
      # db_namespace['schema:dump'].reenable
    end

    desc 'Load a schema.rb file into the database'
    task :load do
      file = ENV['SCHEMA']

      if File.exist?(file)
        load(file)
      else
        abort %{#{file} doesn't exist yet. Run `rake db:migrate` to create it, then try again. If you do not intend to use a database, you should instead alter #{Rails.root}/config/application.rb to limit the frameworks that will be loaded.}
      end
    end
  end

  desc 'Load the seed data from db/seeds.rb'
  task :seed do
    # db_namespace['abort_if_pending_migrations'].invoke
    # ActiveRecord::Tasks::DatabaseTasks.load_seed
    puts '... db/seeds.rb should be loaded here ...'
  end

  desc "Run migrations"
  task :setup, [:version] do |t, args|
    require "sequel"
    Sequel.extension :migration
    db = Sequel.connect(ENV.fetch("DATABASE_URL"))
    if args[:version]
      puts "Migrating to version #{args[:version]}"
      Sequel::Migrator.run(db, "db/migrate", target: args[:version].to_i)
    else
      puts "Migrating to latest"
      Sequel::Migrator.run(db, "db/migrate")
    end
  end
end
