# frozen_string_literal: true
module Ossert
  module Fetch
    # Class implementing `StackOverflow` crawler
    class StackOverflow
      attr_reader :client, :project

      extend Forwardable
      def_delegators :project, :community

      BASE_URL = 'https://api.stackexchange.com/2.2/'
      SEARCH_URL = 'search/advanced'
      SEARCH_PARAMS = {
        site: :stackoverflow,
        tagged: 'ruby',
        filter: :total
      }.freeze

      # Public: Create StackOverflow fetcher
      #
      # project - an object representing a project
      #           it should contain:
      #             - #name method to return String;
      #             - #community accessor to return
      #                 and accept a Hash.
      #
      # Returns nothing.
      def initialize(project)
        @client = SimpleClient.new(BASE_URL)
        @project = project
        @cmn_params = SEARCH_PARAMS.merge(q: "\"#{project.name}\"")
        @cmn_params[:key] = ENV['SO_TOKEN'] if ENV.has_key? 'SO_TOKEN'
      end

      # Public: Trigger fetching
      #
      # Returns nothing.
      def process
        process_questions_total
      end

      private

      # Public: Fetch all related questions
      #
      # Returns a response Hash from SO.
      def fetch_questions(params = {})
        @client.get(SEARCH_URL, @cmn_params.merge(params))
      end

      # Public: Fetch resolved questions
      #
      # Returns a response Hash from SO.
      def fetch_resolved_questions
        fetch_questions accepted: true
      end

      # Public: Fetch & process total stats
      #
      # Returns nothing.
      def process_questions_total
        community.total.questions_count = fetch_questions[:total]
        community.total.questions_resolved_count = fetch_resolved_questions[:total]
      end
    end
  end
end