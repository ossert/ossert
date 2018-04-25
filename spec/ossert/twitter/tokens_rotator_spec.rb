# frozen_string_literal: true

require 'spec_helper'

describe Ossert::Twitter::TokensRotator do
  let(:default_token) { Ossert::Twitter::Credentials.default_access_token }
  let(:extra_token) { Ossert::Twitter::Credentials.access_tokens[1] }
  let(:next_token) { described_class.next_token }

  it 'returns the first token' do
    expect([default_token, extra_token]).to include next_token
  end

  it 'returns the first token if defer time is expired' do
    described_class.defer_token(default_token, Time.now - 5.seconds)

    expect([default_token, extra_token]).to include next_token
  end

  it 'returns extra token if first is defered' do
    described_class.defer_token(default_token, Time.now + 5.seconds)

    expect(next_token).to eq extra_token
  end

  it 'raises an exception if there is no tokens available for now' do
    defer_time = Time.now + 5.seconds
    described_class.defer_token(default_token, defer_time + 1.hour)
    described_class.defer_token(extra_token, defer_time)

    expect { next_token }.to raise_error do |error|
      expect(error).to be_a Ossert::Twitter::TokensRotator::DeferedTokenError
      expect(error.defer_time).to eq defer_time
    end
  end

  after { Redis.current.flushdb }
end
