# frozen_string_literal: true

require 'spec_helper'

describe Ossert::Twitter::TweetsFetcher do
  describe 'call' do
    let(:project) { double(github_alias: 'mperham/sidekiq') }
    let(:fetcher) { described_class.new(project, Ossert::Twitter::Credentials.default) }

    it 'works with 200 response' do
      VCR.use_cassette('twitter/200/valid') do
        tweets = fetcher.call
        expect(tweets.count).to eq 13
      end
    end

    context 'deal with errors' do
      context 'when response is invalid' do
        it 'raises an exception whn response json is invalid' do
          expect { fetch_cassette('twitter/200/invalid') }.to(
            raise_error JSON::Schema::ValidationError
          )
        end
      end

      it 'raises an exception when rate limits are exceeded' do
        expect { fetch_cassette('twitter/429') }.to raise_error do |error|
          expect(error).to be_a Twitter::Error::TooManyRequests

          expect(error.rate_limit.remaining).to eq 0
          expect(error.rate_limit.reset_at).to eq Time.parse('2018-03-13 19:35:41 UTC')
        end
      end
    end

    private

    def fetch_cassette(cassette)
      VCR.use_cassette(cassette) { fetcher.call }
    end
  end
end
