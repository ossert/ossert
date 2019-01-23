# frozen_string_literal: true

require_relative './query'

module Ossert
  module Reddit
    # Simplify Query construction
    class QueryBuilder
      attr_reader :response_limit

      def initialize(subreddits:, response_limit:)
        @subreddits = subreddits
        @response_limit = response_limit
      end

      def submission_search(topic, range)
        build_base_query('/reddit/submission/search', range).tap do |query|
          query.set_param(:q, topic)
        end
      end

      def comment_search(topic, range)
        build_base_query('/reddit/comment/search', range).tap do |query|
          query.set_param(:q, topic)
        end
      end

      def submission_comment_list(topic_id, range)
        build_base_query('/reddit/comment/search', range).tap do |query|
          query.set_param(:link_id, topic_id)
        end
      end

      private

      def build_base_query(path, range)
        Query.new(path: path,
                  range: range,
                  limit: @response_limit,
                  subreddits: @subreddits)
      end
    end
  end
end
