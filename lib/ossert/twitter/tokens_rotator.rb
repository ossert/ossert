# frozen_string_literal: true

require 'ossert/twitter/credentials'
require 'redis'

module Ossert
  module Twitter
    class TokensRotator
      DeferedTokenError = Class.new(StandardError) do
        attr_reader :defer_time

        def initialize(defer_time)
          @defer_time = defer_time
        end
      end

      class << self
        def next_token
         now = Time.now
         defer_times = []
         Credentials.access_tokens.shuffle.each do |token|
            time = time(token_key(token))
            return token if time.nil? || time < now
            defer_times.push(time)
          end
         raise DeferedTokenError.new(defer_times.min)
        end

        def defer_token(token, time)
          redis.set(token_key(token), time.to_i)
        end

        private

        def token_key(token)
          token.fetch(:login)
        end

        def time(token)
          timestamp = redis.get(token).to_i
          timestamp == 0 ? nil : Time.at(timestamp)
        end

        def redis
          Redis.current
        end
      end
    end
  end
end 
