# frozen_string_literal: true
module Ossert
  module Workers
    class ParseExtraData
      include Sidekiq::Worker
      include ForkProcessing
      sidekiq_options unique: :until_executed,
                      unique_expiration: 1.hour,
                      retry: 3

      def unzip_file(buffer, destination)
        require 'zip'
        Zip::File.open(buffer) { |zip_file|
        zip_file.each { |f|
          f_path=File.join(destination, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))
          zip_file.extract(f, f_path) unless File.exist?(f_path)
        }
        }
      end

      def find_filename(project_folder:, name_like:)
        `cd #{project_folder} && ls`.split("\n").select { |fname| !(fname.downcase =~ /#{name_like}/).nil? }.first
      end

      def parse_data(project_name:, project_github_url:)
        # check Wiki existance
        has_wiki = `curl -I -s -o /dev/null -w "%{http_code}" #{project_github_url}/wiki` == "200" # has_wiki?

        client = ::Octokit::Client.new(access_token: Ossert::Fetch::Utils::KeysStorage::GitHub.call)
        zip_link = client.tags(project_github_url.match(Ossert::Fetch::Rubygems::GITHUB_REPO_REGEX).to_a[1..2].join("/")).first[:zipball_url]

        project_folder = File.join(Dir.tmpdir, project_name)
        `rm -rf /tmp/#{project_name}/*`

        unzip_file(open(zip_link), project_folder)

        parent_dir_name = find_filename(project_folder: project_folder, name_like: project_name)

        puts("Nothing extracted for '#{project_name}'") and return {docs_lines: 0, loc: 0, readme_size: 0, has_wiki: has_wiki} if parent_dir_name.nil?

        project_folder = File.join(project_folder, parent_dir_name)

        # run metric_fu (read stats) ??? DEBUG

        Bundler.with_clean_env do
          `(cd #{project_folder} && grep metric_fu Gemfile) || echo "gem 'metric_fu'" >> #{File.join(project_folder, 'Gemfile')}`
        end

        Bundler.with_clean_env do
          `cd #{project_folder} && echo "#{project_name}" > #{project_folder}/.ruby-gemset`
        end

        Bundler.with_clean_env do
          `cd #{project_folder} && bundle install --binstubs`
        end
          # `cd #{project_folder} && rm tmp/metric_fu/_data/*`
        Bundler.with_clean_env do
          `cd #{project_folder} && metric_fu --no-flog --no-churn --no-roodi --no-open`
        end
        stats_yml_path = `cd #{project_folder} && ls tmp/metric_fu/_data/*`.split("\n").first
        stats_yml = YAML.load(open(File.join(project_folder, stats_yml_path)))

        total_lines = stats_yml[:stats][:lines].last # :lines, :loc
        docs_lines = total_lines[:lines] - total_lines[:loc]

        readme_file_name = find_filename(project_folder: project_folder, name_like: 'readme')

        # check Readme size
        readme_size = File.size?(File.join(project_folder, readme_file_name)).to_i

        {docs_lines: docs_lines, loc: total_lines[:loc], readme_size: readme_size, has_wiki: has_wiki}
      end

      def perform(name, reference = Ossert::Saveable::UNUSED_REFERENCE)
        logger.info "Fetching data for: '#{name}' (ref: #{reference})"
        process_in_fork do
          Ossert.init
          Ossert::Project.fetch_all(name, reference)
        end
      end
    end
  end
end


require 'csv'
projects = CSV.read('tmp/most_popular_gems.csv')

projects.in_groups_of(4)[1..2].each do |projects_set|
  # pids = []
  projects_set.each do |project|
    # pids << fork do
      _, project_name, _, project_github_url = project
      begin
        extra_data = parse_data(project_name: project_name, project_github_url: project_github_url)

        Ossert.init
        ::Project.find(name: project_name).update(extra_data: extra_data.to_json)
      rescue => e
        parse_error = "Error: #{e} with project - #{project_name}"
        puts parse_error
        ::Project.find(name: project_name).update(extra_data: {errors: parse_error}.to_json)
      end
    # end
  end

  # pids.each { |pid| waitpid(pid) }
  # pids.clear
  sleep(1)
end
