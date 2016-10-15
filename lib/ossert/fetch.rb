require 'nokogiri'
require 'open-uri'
require 'benchmark'

require 'ossert/fetch/github'
require 'ossert/fetch/rubygems'
require 'ossert/fetch/bestgems'

# TODO: Add logging

module Ossert
  module Fetch
    ALL_FETCHERS = [Rubygems, Bestgems, GitHub]

    def all_by_names(names)
      Array.wrap(names).each do |name|
        puts "Fetching project '#{name}'..."
        all(Project.new(name, nil, name))
        puts "Done."
        sleep(1)
      end
      nil
    end
    module_function :all_by_names

    def all(project)
      ALL_FETCHERS.each do |fetcher|
        puts "======> with #{fetcher}..."
        time = Benchmark.realtime do
          fetcher.new(project).process
        end
        puts "<====== Finished in #{time.round(3)} sec."
        sleep(1)
      end
      nil
    end
    module_function :all

    # Example
    #   projects_without_gh_data = Ossert::Project.projects.select { |proj| proj.gh_alias.blank? }
    #   projects_without_gh_data.each { |prj| Ossert::Fetch.only([Ossert::Fetch::Rubygems, Ossert::Fetch::GitHub], prj) }
    def only(fetchers, project, process = :process)
      fetchers = Array.wrap(fetchers)
      puts "Fetching project '#{project.name}'..."
      (ALL_FETCHERS & fetchers).each do |fetcher|
        puts "======> with #{fetcher}..."
        time = Benchmark.realtime do
          fetcher.new(project).send(process)
        end
        puts "<====== Finished in #{time.round(3)} sec."
        sleep(1)
      end
      nil
    end
    module_function :only

    class SimpleClient
      attr_reader :api_endpoint, :type

      def initialize(api_endpoint, type = nil)
        raise ArgumentError if !api_endpoint.start_with?('http') || !api_endpoint.end_with?('/')
        @api_endpoint = api_endpoint
        @type = type || 'json'
      end

      class NotFound < StandardError; end

      def get(path)
        raise ArgumentError unless path.end_with? type
        response = agent.get("#{api_endpoint}#{path.to_s}")
        case response.status
        when 404
          raise NotFound
        when 200
          JSON.parse(response.body)
        end
      end

      private

      def agent
        @agent ||= ::Faraday.new do |http|
          http.request :url_encoded
          http.adapter :net_http
        end
      end
    end
  end
end
