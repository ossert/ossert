# frozen_string_literal: true

require 'spec_helper'

describe Ossert::Workers::FetchTwitter do
  describe 'perform' do
    it 'retries failed job 3 times' do
      is_expected.to be_retryable 3
    end

    describe 'retry_in' do
      let(:reset_time) { Time.now + 1.day }
      let(:error) { ::Twitter::Error::TooManyRequests.new }

      before do
        allow(error.rate_limit).to receive(:reset_at).and_return reset_time
      end

      it 'retries after rate limit invarval will pass' do
        retry_seconds = subject.sidekiq_retry_in_block.call(1, error)
        expect(retry_seconds).to eq(1.day + 15.seconds)
      end
    end
  end
end
