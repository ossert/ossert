# frozen_string_literal: true
require 'nokogiri'
require 'open-uri'
require 'benchmark'

require 'ossert/fetch/github'
require 'ossert/fetch/rubygems'
require 'ossert/fetch/bestgems'
require 'ossert/fetch/stackoverflow'


module Ossert
  # Public: Various classes and methods for fetching data from different sources.
  # Such as GitHub, Rubygems, Bestgems, StackOverflow. Also provides simple
  # functionality for fetching HTTP API.
  # TODO: Add logging
  module Fetch
    ALL_FETCHERS = [Rubygems, Bestgems, GitHub, StackOverflow].freeze

    # Public: Fetch data for project using all fetchers by default process method
    #
    # project  - The Ossert::Project instance to fill using fetchers
    #
    # Examples
    #
    #   project = Ossert::Project.new('ramaze')
    #   Ossert::Fetch.all(project)
    #   project.dump
    #
    # Returns nothing.
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
    rescue => e
      puts "Fetching Failed for '#{name}' with error: #{e.inspect}"
      puts e.backtrace
    end
    module_function :all

    # Public: Fetch data for project using given fetchers by process method
    #
    # fetchers - The Array or one of Ossert::Fetch::GitHub, Ossert::Fetch::Bestgems,
    #            Ossert::Fetch::Rubygems, Ossert::Fetch::StackOverflow to
    #            use for processing
    # project  - The Ossert::Project instance to fill using fetchers
    # process  - The Symbol method name used for processing by fetchers (default: :process)
    #
    # Examples
    #
    #   project = Ossert::Project.new('ramaze')
    #   Ossert::Fetch.only(Ossert::Fetch::Rubygems, project, :process_meta)
    #   project.dump_attribute :meta_data
    #
    # Returns nothing.
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
    end
    module_function :only

    # Public: Simple client for fetching HTTP API
    #
    # Examples
    #
    #   client = SimpleClient.new("http://bestgems.org/api/v1/")
    #   client.get("gems/#{project.rubygems_alias}/total_downloads.json")
    #   # => Some JSON from api
    class SimpleClient
      attr_reader :api_endpoint, :type

      # Public: Instantiate client for fetching API for given api_endpoint and response type
      #
      # path - The String describes path of endpoint to access the data
      # type - The String describes type of response data, e.g. 'json'
      #
      # Examples
      #
      #   client = SimpleClient.new("http://bestgems.org/api/v1/")
      #   client.get("gems/#{project.rubygems_alias}/total_downloads.json")
      #   # => Some JSON from api
      #
      # Returns nothing.
      def initialize(api_endpoint, type = nil)
        raise ArgumentError if !api_endpoint.start_with?('http') || !api_endpoint.end_with?('/')
        @api_endpoint = api_endpoint
        @type = type || 'json'
      end

      class NotFound < StandardError; end
      class UnexpectedResponseError < StandardError; end
      class WrongContentType < StandardError; end
      class RateLimitExceeded < StandardError; end

      # Public: Get data via HTTP GET for given API path
      #
      # path - The String describes path of endpoint to access the data
      #
      # Examples
      #
      #   client = SimpleClient.new("http://bestgems.org/api/v1/")
      #   client.get("gems/#{project.rubygems_alias}/total_downloads.json")
      #   # => Some JSON from api
      #
      # Returns nothing.
      def get(path, params = nil)
        response = agent.get("#{@api_endpoint}#{path}", params)

        case response.status
        when 404
          raise NotFound
        when 429
          raise RateLimitExceeded
        when 200
          JSON.parse(response.body, symbolize_names: true)
        else
          raise UnexpectedResponseError
        end
      end

      private

      # Internal: Initialize Faraday agent for processing requests
      #
      # Returns Faraday::Connection instance.
      def agent
        @agent ||= ::Faraday.new do |http|
          http.request :url_encoded
          http.adapter :net_http
        end
      end
    end
  end
end
