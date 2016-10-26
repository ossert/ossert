module Ossert
  module Fetch
    class Rubygems
      attr_reader :client, :project

      extend Forwardable
      def_delegators :project, :agility, :community, :meta

      def initialize(project)
        @client = SimpleClient.new("https://rubygems.org/api/v1/")
        @project = project
      end

      def info
        @info ||= client.get("gems/#{project.rubygems_alias}.json")
      end

      def version_info
        @info ||= client.get("versions/#{project.rubygems_alias}.json")
      end

      def releases
        @releases ||= client.get("versions/#{project.rubygems_alias}.json")
      end

      def reversed_dependencies
        client.get("/gems/#{project.rubygems_alias}/reverse_dependencies.json")
      end

      def process_meta
        meta[:homepage_url] = info['homepage_uri']
        meta[:docs_url] = info['documentation_uri']
        meta[:wiki_url] = info['wiki_uri']
        meta[:source_url] = info['source_code_uri']
        meta[:issue_tracker_url] = info['bug_tracker_uri']
        meta[:authors] = info['authors']
        meta[:description] = info['info']
        meta[:current_version] = info['version']
        meta[:mailing_list_url] = info['mailing_list_uri']
        meta[:rubygems_url] = info['project_uri']
        meta[:github_url] = "https://github.com/#{project.github_alias}" # or exception!
      end

      def process
        if project.github_alias.blank?
          match = info['source_code_uri'].try(:match, /github.com\/([a-zA-Z0-9\.\_\-]+)\/([a-zA-Z0-9\.\_\-]+)/)
          match ||= info['homepage_uri'].try(:match, /github.com\/([a-zA-Z0-9\.\_\-]+)\/([a-zA-Z0-9\.\_\-]+)/)
          project.github_alias = "#{match[1]}/#{match[2]}" if match
        end

        agility.total.dependencies += info['dependencies']['runtime']
        community.total.dependants += reversed_dependencies

        releases.each do |release|
          agility.total.releases_total_rg << release['number']
          agility.quarters[release['created_at']].releases_total_rg << release['number']
        end

        process_meta
      end
    end
  end
end
