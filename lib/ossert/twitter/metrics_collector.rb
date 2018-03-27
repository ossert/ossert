# frozen_string_literal: true

module Ossert
  module Twitter
    # Calculates metrics of passed tweets
    class MetricsCollector
      attr_reader :tweets

      def initialize(tweets)
        @tweets = tweets
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def call
        empty_metrics.tap do |metrics|
          processed_user_ids = Set.new

          tweets.each do |tweet|
            metrics[:tweets_count] += 1
            metrics[:replies_count] += 1 if tweet.reply?
            metrics[:retweets_count] += 1 if tweet.retweet?
            metrics[:favorites_count] += tweet.favorite_count
            metrics[:coverage] += tweet.user.followers_count

            processed_user_ids.add(tweet.user.id)
          end

          metrics[:twitters_count] = processed_user_ids.count
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      private

      def empty_metrics
        {
          tweets_count: 0,
          favorites_count: 0,
          replies_count: 0,
          retweets_count: 0,
          coverage: 0,
          twitters_count: 0
        }
      end
    end
  end
end
