namespace :db do
  task :load_config do
    require 'rom-sql'
    require 'rom-repository'

    $rom_conf = ROM::Configuration.new(:sql, ENV.fetch("DATABASE_URL"))
  end

  desc 'Create the database, load the schema, and initialize with the seed data (use db:reset to also drop the db first)'
  task :setup => ['db:schema:load']

  namespace :schema do
    desc 'Load a schema.rb file into the database'
    task :load => [:load_config] do
      file = ENV['SCHEMA']

      if File.exist?(file)
        load(file)
      else
        abort %{#{file} doesn't exist yet. Run `rake db:migrate` to create it, then try again. If you do not intend to use a database, you should instead alter #{Rails.root}/config/application.rb to limit the frameworks that will be loaded.}
      end
    end
  end

  task :drop do
    db = Sequel.connect(ENV.fetch("DATABASE_URL"))
    db.run(<<-SQL)
      DROP SCHEMA public CASCADE;
    SQL
  end

  task :create do
    sh "createdb #{ENV.fetch("DATABASE_URL").split('/').last}"
    # FIXME: not working correct
    # db = Sequel.connect(ENV.fetch("DATABASE_URL"))
    # db.run(<<-SQL)
    #   CREATE SCHEMA IF NOT EXISTS public;
    #   GRANT ALL ON SCHEMA public TO postgres;
    #   GRANT ALL ON SCHEMA public TO public;
    #   COMMENT ON SCHEMA public IS 'standard public schema';
    # SQL
  end

  desc "Dumps the database to backups"
  task :dump, [:fmt] do |t, args|
    dump_fmt = args.fmt || 'c' # or 'p', 't', 'd'
    dump_sfx = suffix_for_format dump_fmt
    backup_dir = backup_directory true
    cmd = nil
    with_config do |app, db_url|
      file_name = Time.now.strftime("%Y%m%d%H%M%S") + "_" + app + '_db.' + dump_sfx
      cmd = "pg_dump #{db_url} --no-owner --no-acl -F #{dump_fmt} -v -f #{backup_dir}/#{file_name}"
    end
    puts cmd
    sh cmd do
      # Ignore errors
    end
  end

  desc "Show the existing database backups"
  task :list_backups do
    backup_dir = backup_directory
    puts "#{backup_dir}"
    exec "/bin/ls -lht #{backup_dir}"
  end

  desc "Restores the database from a backup using PATTERN"
  task :restore, [:pat] do |t, args|
    if args.pat.present?
      cmd = nil
      with_config do |app, db_url|
        backup_dir = backup_directory
        files = Dir.glob("#{backup_dir}/*#{args.pat}*")
        case files.size
        when 0
          puts "No backups found for the pattern '#{args.pat}'"
        when 1
          file = files.first
          fmt = format_for_file file
          if fmt.nil?
            puts "No recognized dump file suffix: #{file}"
          else
            cmd = "pg_restore -d '#{db_url}' -F #{fmt} -v -c #{file}"
          end
        else
          puts "Too many files match the pattern '#{args.pat}':"
          puts ' ' + files.join("\n ")
          puts "Try a more specific pattern"
        end
      end
      unless cmd.nil?
        Rake::Task["db:drop"].invoke
        puts cmd
        exec cmd << " || exit 0"
      end
    else
      puts 'Please pass a pattern to the task'
    end
  end

  namespace :restore do
    desc "Restores the database from latest backup"
    task :last do |t, args|
      cmd = nil
      with_config do |app, db_url|
        backup_dir = backup_directory
        file = Dir.glob("#{backup_dir}/*").max_by {|f| File.mtime(f)}
        if file
          fmt = format_for_file file
          if fmt.nil?
            puts "No recognized dump file suffix: #{file}"
          else
            cmd = "pg_restore -d '#{db_url}' -F #{fmt} -v -c #{file}"
          end
        else
          puts "No backups found"
        end
      end
      unless cmd.nil?
        Rake::Task["db:drop"].invoke
        puts cmd
        exec cmd << " || exit 0"
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
      else nil
      end
  end

  def format_for_file(file)
    case file
    when /\.dump$/ then 'c'
    when /\.sql$/  then 'p'
    when /\.dir$/  then 'd'
    when /\.tar$/  then 't'
    else nil
    end
  end

  def backup_directory(create=false)
    backup_dir = "db/backups"
    if create and not Dir.exists?(backup_dir)
      puts "Creating #{backup_dir} .."
      Dir.mkdir_p(backup_dir)
    end
    backup_dir
  end

  def with_config
    yield 'ossert', ENV.fetch("DATABASE_URL")
  end
end
