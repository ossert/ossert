# frozen_string_literal: true

require 'spec_helper'

describe Ossert::Workers::FetchTwitter do
  it 'retries failed job 3 times' do
    is_expected.to be_retryable 5
  end

  describe 'perform' do
    context 'when rate limit' do
      pending
    end
  end

  describe 'retry_in' do
    let(:defer_time) { Time.now + 1.day }
    let(:error) do
      Ossert::Twitter::TokensRotator::DeferedTokenError.new(defer_time)
    end

    it 'retries after rate limit invarval will pass' do
      retry_seconds = subject.sidekiq_retry_in_block.call(1, error)
      expect(retry_seconds).to eq(1.day)
    end
  end
end
