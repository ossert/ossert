# frozen_string_literal: true

require 'spec_helper'

describe Ossert::Twitter::MetricsCollector do
  describe 'new' do
    let(:collector) { described_class.new(tweets) }

    context 'tweet without reply and retweet' do
      let(:tweets) do
        [
          ::Twitter::Tweet.new(
            {
              id: 123,
              favorite_count: 12, 
              user: {
                followers_count: 3, id: '1'
              }
            }
          )
        ]
      end

      it do
        expect(collector.call).to have_attributes(
          tweets_count: 1,
          replies_count: 0,
          retweets_count: 0,
          favorites_count: 12,
          coverage: 3,
          twitters_count: 1
        )
      end
    end

    context 'one tweet with reply and retweet' do
      let(:tweets) do
        [
          ::Twitter::Tweet.new(
            {
              id: 123,
              in_reply_to_user_id: 123,
              retweeted_status: {id: 123},
              favorite_count: 12,
              user: {
                followers_count: 3, id: 1
              }
            }
          )
        ]
      end

      it do
        expect(collector.call).to have_attributes(
          tweets_count: 1,
          replies_count: 1,
          retweets_count: 1,
          favorites_count: 12,
          coverage: 3,
          twitters_count: 1
        )
      end
    end

    context 'several tweets with reply and retweet' do
      let(:tweets) do
        [
          {
            id: 123,
            in_reply_to_user_id: 123,
            retweeted_status: {
              id: 123
            },
            favorite_count: 12,
            user: {
              followers_count: 3,
              id: 1
            }
          },
          {
            id: 123,
            retweeted_status: {
              id: 123
            },
            favorite_count: 52,
            user: {
              followers_count: 5,
              id: 4
            }
          }
        ].map { |j| ::Twitter::Tweet.new(j) }
      end

      it do
        expect(collector.call).to have_attributes(
          tweets_count: 2,
          replies_count: 1,
          retweets_count: 2,
          favorites_count: 64,
          coverage: 8,
          twitters_count: 2
        )
     end
    end
  end
end
