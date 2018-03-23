# frozen_string_literal: true

require 'ossert/twitter/search_results_validator'

module Ossert
  module Twitter
    class TweetsFetcher
      DEFAULT_TIMEOUTS = { connect: 2.seconds, read: 2.seconds }.freeze
      attr_reader :project, :credentials, :timeouts

      def initialize(project, credentials, timeouts = nil)
        @project = project
        @credentials = credentials
        @timeouts = timeouts || DEFAULT_TIMEOUTS
      end

      def call
        Ossert::Twitter::SearchResultsValidator.validate! do
          client.search(search_query)
        end
      end

      private

      def search_query
        "\"#{project.github_alias}\""
      end

      def client
        @client ||= ::Twitter::REST::Client.new(
          Credentials.default.merge(timeouts: timeouts)
        )
      end
    end
  end
end
