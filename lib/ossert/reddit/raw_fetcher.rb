# frozen_string_literal: true

require_relative './query_builder'

module Ossert
  module Reddit
    # Data fetcher in a hash format
    class RawFetcher
      REQUST_LIMIT_PER_MINUTE = 180
      MAX_ATTEMPTS_TO_FETCH = 3
      AWAIT_BEFORE_RETRY = 3
      SUBREDDITS = %w[ruby rails learn_ruby].freeze
      COMMENT_FIELDS = %i[id created_utc score author link_id].freeze
      SUBMISSION_FIELDS = %i[title name id created_utc score author
                             num_comments full_link author].freeze

      def initialize(client)
        @client = client
        @query_builder = QueryBuilder.new(subreddits: SUBREDDITS)
      end

      def submissions(topic, time_range = nil)
        query = @query_builder.submission_search(topic, time_range)
        fetch_data(query, SUBMISSION_FIELDS)
      end

      def comments(topic, time_range = nil)
        query = @query_builder.comment_search(topic, time_range)
        fetch_data(query, COMMENT_FIELDS)
      end

      private

      def fetch_data(query, fields)
        fetch_all_portions(query, fields).map(&:data).flatten
      end

      # keep fetching reducing the range until we get all of results
      def fetch_all_portions(query, fields)
        portions = []
        loop do
          portion = ResponsePortion.new(fetch_json(query), fields)
          portions << portion
          return portions if portion.exhaustive_for?(query)

          query[:before] = portion.last_item_creation_time
        end
      end

      def fetch_json(query)
        @fetch_attempts = 0
        ensure_rate_limits
        try_to_fetch(query)
      end

      def try_to_fetch(query)
        @client.get(*query.to_param_list)[:data]
      rescue StandardError => error
        raise error unless @fetch_attempts < MAX_ATTEMPTS_TO_FETCH

        puts "Got an error #{error} retrying..."
        sleep AWAIT_BEFORE_RETRY
        @fetch_attempts += 1
        retry
      end

      # just keep average pace
      def ensure_rate_limits
        sleep 1 / REQUST_LIMIT_PER_MINUTE.to_f
      end

      # Sometimes it's not possible to get all data in a single request
      class ResponsePortion
        attr_reader :data

        def initialize(data, fields)
          @data = data.map do |item|
            item.select { |key| fields.include? key }
          end
        end

        def exhaustive_for?(query)
          @data.length < query.limit
        end

        def last_item_creation_time
          raise 'Portion is empty' if @data.empty?

          @data.last[:created_utc]
        end
      end
    end
  end
end
