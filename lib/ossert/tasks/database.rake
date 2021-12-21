# frozen_string_literal: true

require 'dotenv'
Dotenv.load('.env.test.local', '.env.test')

require 'uri'

namespace :db do
  require 'sequel'
  Sequel.extension :migration

  def create_db(uri)
    database_name = uri.path.split('/').last
    sh "createdb #{db_opts(uri)} #{database_name}"
  end

  def drop_db(uri)
    database_name = uri.path.split('/').last
    sh "dropdb #{db_opts(uri)} --if-exists #{database_name}"
  end

  def db_opts(uri)
    host = uri.host || 'localhost'
    ["-h #{host}"].tap do |opts|
      opts << "-U #{uri.user}" if uri.user
    end.join(' ')
  end

  namespace :test do
    task :prepare do
      uri = URI(ENV.fetch('DATABASE_URL'))

      drop_db(uri)
      create_db(uri)

      DB = Sequel.connect(uri.to_s)

      Sequel::Migrator.run(DB, File.expand_path('../../../db/migrate', __dir__))
      Rake::Task['db:version'].execute
    end
  end

  task migrate: :load_config do
    Sequel::Migrator.run(DB, File.expand_path('../../../db/migrate', __dir__))
    Rake::Task['db:version'].execute
  end

  task rollback: :load_config do
    if (version = current_version).positive?
      Sequel::Migrator.run(
        DB,
        File.expand_path('../../../db/migrate', __dir__),
        target: version - ENV.fetch('STEP', 1).to_i
      )
    end

    Rake::Task['db:version'].execute
  end

  desc 'Prints current schema version'
  task :version do
    puts "Schema Version: #{current_version}"
  end

  task :load_config do
    DB = Sequel.connect(ENV.fetch('DATABASE_URL'))
  end

  desc 'Create the database, load the schema, and initialize with the seed data (db:reset to also drop the db first)'
  task :setup do
    Rake::Task['db:drop'].invoke
    Rake::Task['db:create'].invoke
    Rake::Task['db:load_config'].invoke

    Sequel::Migrator.run(DB, File.expand_path('../../../db/migrate', __dir__))
    Rake::Task['db:version'].execute
  end

  task :drop do
    drop_db(URI(ENV.fetch('DATABASE_URL')))
  end

  task :create do
    create_db(URI(ENV.fetch('DATABASE_URL')))
  end

  desc 'Dumps the database to backups'
  task :dump, [:fmt] do |_, args|
    dump_fmt = args.fmt || 'c' # or 'p', 't', 'd'
    dump_sfx = suffix_for_format dump_fmt
    backup_dir = backup_directory true
    cmd = nil
    with_config do |app, db_url|
      file_name = Time.now.strftime('%Y%m%d%H%M%S') + '_' + app + '_db.' + dump_sfx
      cmd = "pg_dump #{db_url} --no-owner --no-acl -F #{dump_fmt} -v -f #{backup_dir}/#{file_name}"
    end
    puts cmd
    sh cmd do
      # Ignore errors
    end
  end

  desc 'Show the existing database backups'
  task :list_backups do
    backup_dir = backup_directory
    puts backup_dir.to_s
    exec "/bin/ls -lht #{backup_dir}"
  end

  desc 'Restores the database from a backup using PATTERN'
  task :restore, [:pat] do |_, args|
    puts 'Please pass a pattern to the task' unless args.pat.present?
    cmd = nil
    with_config do |_, db_url|
      cmd = command_for_files args.pat, db_url
    end
    unless cmd.nil?
      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke
      puts cmd
      exec "#{cmd} || exit 0"
    end
  end

  def command_for_files(pattern, db_url)
    files = Dir.glob("#{backup_directory}/*#{pattern}*")
    case files.size
    when 0
      puts "No backups found for the pattern '#{pattern}'"
    when 1
      command_for_file files.first, db_url
    else
      puts "Too many files match the pattern '#{pattern}': #{files.join("\n ")} "
      puts 'Try a more specific pattern'
    end
  end

  def command_for_file(file, db_url)
    return puts("No recognized dump file suffix: #{file}") unless (fmt = format_for_file(file)).present?

    "pg_restore -d '#{db_url}' -F #{fmt} -v -c #{file}"
  end

  namespace :restore do
    desc 'Restores the database from latest backup'
    task :last do
      cmd = nil
      with_config do |_, db_url|
        file = Dir.glob("#{backup_directory}/*").max_by { |f| File.mtime(f) }
        if file
          fmt = format_for_file file
          if fmt.nil?
            puts "No recognized dump file suffix: #{file}"
          else
            cmd = "pg_restore -d '#{db_url}' -F #{fmt} -v #{file}"
          end
        else
          puts 'No backups found'
        end
      end
      unless cmd.nil?
        Rake::Task['db:drop'].invoke
        Rake::Task['db:create'].invoke
        puts cmd
        exec "#{cmd} || exit 0"
      end
    end
  end

  private

  def suffix_for_format(suffix)
    case suffix
    when 'c' then 'dump'
    when 'p' then 'sql'
    when 't' then 'tar'
    when 'd' then 'dir'
    end
  end

  def format_for_file(file)
    case file
    when /\.dump$/ then 'c'
    when /\.sql$/  then 'p'
    when /\.dir$/  then 'd'
    when /\.tar$/  then 't'
    end
  end

  def backup_directory(create = false)
    backup_dir = 'db/backups'
    if create && !Dir.exist?(backup_dir)
      puts "Creating #{backup_dir} .."
      FileUtils.mkdir_p(backup_dir)
    end
    backup_dir
  end

  def with_config
    yield 'ossert', ENV.fetch('DATABASE_URL')
  end

  def current_version
    DB.tables.include?(:schema_info) && DB[:schema_info].first[:version] || 0
  end
end
