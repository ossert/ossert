namespace :db do
  namespace :test do
    task :prepare do
      test_database_url = ENV.fetch("TEST_DATABASE_URL")
      database_name = test_database_url.split('/').last

      ROM::Configuration.new(:sql, test_database_url)

      sh "dropdb #{database_name}" do
        # Ignore errors
      end

      sh "createdb #{database_name}" do
        # Ignore errors
      end

      ROM::SQL::RakeSupport.run_migrations
    end
  end

  task :load_config do
    ROM::Configuration.new(:sql, ENV.fetch("DATABASE_URL"))
  end

  desc 'Create the database, load the schema, and initialize with the seed data (use db:reset to also drop the db first)'
  task :setup do
    Rake::Task['db:create'].invoke
    Rake::Task['db:load_config'].invoke

    ROM::SQL::Gateway.instance.migrator.instance_variable_set(
      :@path,
      File.expand_path('../../../../db/migrate', __FILE__)
    )

    ROM::SQL::RakeSupport.run_migrations
  end

  task :drop do
    sh "dropdb #{ENV.fetch("DATABASE_URL").split('/').last}" do
      # Ignore errors
    end
  end

  task :create do
    sh "createdb #{ENV.fetch("DATABASE_URL").split('/').last}" do
      # Ignore errors
    end
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
            cmd = "pg_restore -d '#{db_url}' -F #{fmt} -v #{file}"
          end
        else
          puts "No backups found"
        end
      end
      unless cmd.nil?
        Rake::Task["db:drop"].invoke
        Rake::Task["db:create"].invoke
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
