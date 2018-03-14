# frozen_string_literal: true

require 'spec_helper'

describe Ossert::Twitter::Credentials do
  describe 'default' do
    let(:credentials) { described_class.default }

    it 'initializes with ENV variables' do
      expect(credentials).to include(
        consumer_key: ENV.fetch('TWITTER_CONSUMER_KEY'),
        consumer_secret: ENV.fetch('TWITTER_CONSUMER_SECRET'),
        access_token: ENV.fetch('TWITTER_ACCESS_TOKEN'),
        access_token_secret: ENV.fetch('TWITTER_ACCESS_TOKEN_SECRET')
      )
    end
  end
end
