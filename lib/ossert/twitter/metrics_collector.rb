# frozen_string_literal: true

require_relative 'metrics'

module Ossert
  module Twitter
    # Calculates metrics of passed tweets
    class MetricsCollector
      attr_reader :tweets

      def initialize(tweets)
        @tweets = tweets
      end
      
      def call
        Metrics.new.tap do |metrics|
          processed_user_ids = Set.new

          tweets.each do |tweet|
            metrics.tweets_count += 1
            metrics.replies_count += 1 if tweet.reply?
            metrics.retweets_count += 1 if tweet.retweet?
            metrics.favorites_count += tweet.favorite_count

            metrics.coverage += tweet.user.followers_count

            processed_user_ids.add(tweet.user.id)
          end

          metrics.twitters_count = processed_user_ids.count
        end
      end
    end
  end
end
