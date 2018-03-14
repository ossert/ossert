# frozen_string_literal: true

module Ossert
  module Twitter
    # Transfer object for twitter metrics
    Metrics = Struct.new(:tweets_count, :favorites_count, :replies_count,
                         :retweets_count, :coverage, :twitters_count) do

      # Initializes new instance with zero values
      def initialize
        super(0, 0, 0, 0, 0, 0)
      end
    end
  end
end
