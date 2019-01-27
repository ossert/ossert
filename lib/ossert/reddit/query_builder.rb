# frozen_string_literal: true

require_relative './query'

module Ossert
  module Reddit
    # Query Builder for common cases
    class QueryBuilder
      LIMIT = 1000

      attr_reader :response_limit

      def initialize(subreddits:)
        @subreddits = subreddits
      end

      def submission_search(topic, range = nil)
        build_base_query('reddit/submission/search', range).tap do |query|
          query[:q] = topic
        end
      end

      def comment_search(topic, range = nil)
        build_base_query('reddit/comment/search', range).tap do |query|
          query[:q] = topic
        end
      end

      private

      def build_base_query(path, range)
        Query.new(path, default_query_params).tap do |query|
          query.range = range if range
        end
      end

      def default_query_params
        { limit: LIMIT,
          sort: :desc,
          sort_type: :created_utc,
          subreddit: @subreddits.join(',') }
      end
    end
  end
end
