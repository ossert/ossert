# frozen_string_literal: true

require 'spec_helper'

describe Ossert::Twitter::Credentials do
  describe 'consumer_key' do
    let(:consumer_key) { described_class.consumer_key }

    it 'loads consumer key from env variables' do
      expect(consumer_key).to eq(
        consumer_key: ENV.fetch('TWITTER_CONSUMER_KEY'),
        consumer_secret: ENV.fetch('TWITTER_CONSUMER_SECRET')
      )
    end
  end

  describe 'default_access_token' do
    let(:access_token) { described_class.default_access_token }

    it 'loads default access token from env variables' do
      expect(access_token).to eq(
        login: ENV.fetch('TWITTER_LOGIN'),
        access_token: ENV.fetch('TWITTER_ACCESS_TOKEN'),
        access_token_secret: ENV.fetch('TWITTER_ACCESS_TOKEN_SECRET')
      )
    end
  end

  describe 'default' do
    let(:default) { described_class.default }

    it { expect(default).to eq described_class.consumer_key.merge(described_class.default_access_token) }
  end

  describe 'access_tokens' do
    it do
      expect(described_class.access_tokens).to match_array([
        described_class.default_access_token,
        {
          login: ENV.fetch('TWITTER_LOGIN1'),
          access_token: ENV.fetch('TWITTER_ACCESS_TOKEN1'),
          access_token_secret: ENV.fetch('TWITTER_ACCESS_TOKEN_SECRET1')
        }
      ])
    end
  end
end
