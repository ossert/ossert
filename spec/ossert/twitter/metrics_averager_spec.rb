# frozen_string_literal: true

describe Ossert::Twitter::MetricsAverager do
  let(:previous_date) { Date.new(2018, 3, 19) }
  let(:previous_metrics) { { tweets_count: 5.0 } }
  let(:average) do
    described_class
      .new(previous_date: previous_date, previous_metrics: previous_metrics)
      .call(next_date: next_date, next_metrics: next_metrics)
  end

  context 'averages for the same date(use new value)' do
    let(:next_date) { Date.new(2018, 3, 19) }
    let(:next_metrics) { { tweets_count: 6.0 } }

    it { expect(average[:tweets_count]).to eq(6.0) }
  end

  context 'averages for the next day(counts average)' do
    let(:next_date) { Date.new(2018, 3, 20) }
    let(:next_metrics) { { tweets_count: 7.0 } }

    it { expect(average[:tweets_count]).to eq(6.0) }
  end

  context 'averages for the future day' do
    let(:next_date) { Date.new(2018, 3, 22) }
    let(:next_metrics) { { tweets_count: 6.0 } }

    it { expect(average[:tweets_count]).to eq(5.25) }
  end
end
