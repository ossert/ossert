# frozen_string_literal: true

require 'virtus'

module Ossert
  module Twitter
    # Transfer object for twitter metrics
    class Metrics
      include Virtus.model

      attribute :tweets_count, Float, default: 0.0
      attribute :favorites_count, Float, default: 0.0
      attribute :replies_count, Float, default: 0.0
      attribute :retweets_count, Float, default: 0.0
      attribute :coverage, Float, default: 0.0
      attribute :twitters_count, Float, default: 0.0
    end
  end
end
