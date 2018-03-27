# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength
describe Ossert::Twitter::MetricsCollector do
  describe 'new' do
    let(:collector) { described_class.new(tweets) }
    let(:tweets) { json.map { |j| ::Twitter::Tweet.new(j) } }
    let(:json) do
      symbolize_keys!(JSON.parse(File.read('spec/fixtures/twitter/' + fixture_file)))
    end

    context 'tweet without reply and retweet' do
      let(:fixture_file) { 'tweet_without_reply.json' }
      it do
        expect(collector.call).to eq(
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
      let(:fixture_file) { 'tweet_with_reply.json' }

      it do
        expect(collector.call).to eq(
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
      let(:fixture_file) { 'tweets.json' }

      it do
        expect(collector.call).to eq(
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
# rubocop:enable Metrics/BlockLength
