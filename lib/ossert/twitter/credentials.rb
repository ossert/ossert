# frozen_string_literal: true

require 'redis'

module Ossert
  module Twitter
    # Twitter API access tokens
    class Credentials
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
          return @access_tokens unless @access_tokens.nil?
          @access_tokens = [default_access_token]

          i = 1
          while (access_token = ENV["TWITTER_ACCESS_TOKEN#{i}"]) != nil do
            @access_tokens.push(
              login: ENV.fetch("TWITTER_LOGIN#{i}"),
              access_token: access_token,
              access_token_secret: ENV.fetch("TWITTER_ACCESS_TOKEN_SECRET#{i}")
            )
            i += 1
          end
          @access_tokens
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
