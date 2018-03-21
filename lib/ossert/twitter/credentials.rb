# frozen_string_literal: true

module Ossert
  module Twitter
    # Twitter API access tokens
    class Credentials
      class << self
        def default
          @default ||= {
            consumer_key: ENV.fetch('TWITTER_CONSUMER_KEY'),
            consumer_secret: ENV.fetch('TWITTER_CONSUMER_SECRET'),
            access_token: ENV.fetch('TWITTER_ACCESS_TOKEN'),
            access_token_secret: ENV.fetch('TWITTER_ACCESS_TOKEN_SECRET')
          }
        end
      end
    end
  end
end
