# frozen_string_literal: true

require_relative './query_builder'

module Ossert
  module Reddit
    # Fetch data
    class RawFetcher
      BASE_URI = 'https://api.pushshift.io'
      # maximum amount of items possible for a single response
      RESPONSE_LIMIT = 1000
      REQUST_LIMIT_PER_MINUTE = 180
      SUBREDDITS = %w[ruby rails learn_ruby].freeze
      COMMENT_FIELDS = %w[id created_utc score author link_id].freeze
      SUBMISSION_FIELDS = %w[title name id created_utc score author
                             num_comments full_link author].freeze

      def initialize
        @connection = Faraday.new(BASE_URI)
        @query_builder = QueryBuilder.new(subreddits: SUBREDDITS,
                                          response_limit: RESPONSE_LIMIT)
      end

      def submissions(topic, time_range)
        query = @query_builder.submission_search(topic, time_range)
        fetch_data(query, SUBMISSION_FIELDS)
      end

      def comments(topic, time_range)
        query = @query_builder.comment_search(topic, time_range)
        fetch_data(query, COMMENT_FIELDS)
      end

      def submission_comments(id, time_range)
        query = @query_builder.submission_comment_list(id, time_range)
        fetch_data(query, COMMENT_FIELDS)
      end

      private

      def fetch_data(query, fields)
        fetch_all_portions(query, fields).map(&:data).flatten
      end

      # keep fetching reducing the range until we get all of results
      def fetch_all_portions(query, fields)
        slices = []
        loop do
          slice = ResponsePortion.new(fetch_json(query), fields)
          slices << slice
          return slices if slice.exhaustive_for?(query)

          query.set_param(:before, slice.last_item_creation_time)
        end
      end

      def fetch_json(query)
        ensure_rate_limits
        response = @connection.get(*query.to_faraday_param_list)
        Oj.load(response.body)['data']
      end

      # just keep average pace
      def ensure_rate_limits
        sleep 1 / REQUST_LIMIT_PER_MINUTE.to_f
      end

      # Sometimes it's not possible to get all data in a single request
      class ResponsePortion
        attr_reader :data

        def initialize(data, fields)
          @data = data.map { |item| item.slice(*fields) }
        end

        def exhaustive_for?(query)
          @data.length < query.limit
        end

        def last_item_creation_time
          raise 'slice is empty' if @data.empty?

          @data.last['created_utc']
        end
      end
    end
  end
end
