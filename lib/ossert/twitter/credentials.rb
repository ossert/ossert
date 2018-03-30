# frozen_string_literal: true

require 'redis'

module Ossert
  module Twitter
    # Twitter API access tokens
    class Credentials
      MAX_TOKENS = 100
      class << self
        def consumer_key
          @consumer_key ||= {
            consumer_key: ENV.fetch('TWITTER_CONSUMER_KEY'),
            consumer_secret: ENV.fetch('TWITTER_CONSUMER_SECRET')
          }
        end

        def default
          consumer_key.merge(default_access_token)
        end

        def access_tokens
          @access_tokens ||=
            (1..MAX_TOKENS).to_a.each_with_object([default_access_token]) do |index, tokens|
              next if (access_token = ENV["TWITTER_ACCESS_TOKEN#{index}"]).nil?

              tokens.push(
                login: ENV.fetch("TWITTER_LOGIN#{index}"),
                access_token: access_token,
                access_token_secret: ENV.fetch("TWITTER_ACCESS_TOKEN_SECRET#{index}")
              )
            end
        end

        def default_access_token
          @default_access_token ||= {
            login: ENV.fetch('TWITTER_LOGIN'),
            access_token: ENV.fetch('TWITTER_ACCESS_TOKEN'),
            access_token_secret: ENV.fetch('TWITTER_ACCESS_TOKEN_SECRET')
          }
        end
     end
    end
  end
end
