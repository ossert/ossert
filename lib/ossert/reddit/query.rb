# frozen_string_literal: true

module Ossert
  module Reddit
    # Query with Params
    class Query
      extend Forwardable
      attr_reader :params, :path, :limit

      def initialize(path:, range:, limit:, subreddits:)
        @path = path
        @limit = limit
        @params = { limit: limit,
                    sort: :desc,
                    sort_type: :created_utc,
                    subreddit: subreddits.join(','),
                    before: range.before,
                    after: range.after }
      end

      def to_faraday_param_list
        [@path, @params]
      end

      def set_param(name, value)
        @params[name] = value
      end
    end
  end
end
