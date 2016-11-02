# frozen_string_literal: true
module Ossert
  module Fetch
    class Rubygems
      attr_reader :client, :project

      extend Forwardable
      def_delegators :project, :agility, :community, :meta

      def initialize(project)
        @client = SimpleClient.new('https://rubygems.org/api/v1/')
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
        meta[:authors] = info['authors']
        meta[:description] = info['info']
        meta[:current_version] = info['version']
      end

      def process_links
        meta.merge!(
          homepage_url: info['homepage_uri'],
          docs_url: info['documentation_uri'],
          wiki_url: info['wiki_uri'],
          source_url: info['source_code_uri'],
          issue_tracker_url: info['bug_tracker_uri'],
          mailing_list_url: info['mailing_list_uri'],
          rubygems_url: info['project_uri'],
          github_url: "https://github.com/#{project.github_alias}" # or exception!
        )
      end

      def process_github_alias
        return unless project.github_alias.blank?
        match = info['source_code_uri'].try(:match, %r{github.com/([a-zA-Z0-9\.\_\-]+)/([a-zA-Z0-9\.\_\-]+)})
        match ||= info['homepage_uri'].try(:match, %r{github.com/([a-zA-Z0-9\.\_\-]+)/([a-zA-Z0-9\.\_\-]+)})
        project.github_alias = match ? "#{match[1]}/#{match[2]}" : NO_GITHUB_NAME
      end

      def process_releases
        releases.each do |release|
          agility.total.releases_total_rg << release['number']
          agility.quarters[release['created_at']].releases_total_rg << release['number']
        end
      end

      def process_dependencies
        agility.total.dependencies = Set.new(info['dependencies']['runtime']).to_a
        community.total.dependants = Set.new(reversed_dependencies).to_a
      end

      def process
        process_github_alias

        process_dependencies
        process_releases

        process_meta
        process_links
      end
    end
  end
end
