# frozen_string_literal: true

require 'spec_helper'

describe Ossert::Twitter::MetricsUpdater do
  let!(:project) { ::Project.create(name: 'pp', github_name: 'pp/pp', rubygems_name: 'pp', reference: 'ClassA') }
  let(:date) { Date.new(2018, 3, 20) }
  let(:record) { ::TwitterMetrics.where(date: date.monday, project_id: project.id).first }
  let(:metrics) do
    { tweets_count: 111, favorites_count: 0, twitters_count: 0,
      coverage: 0, replies_count: 0, retweets_count: 0 }
  end

  before { described_class.new(project).call(date: date, metrics: metrics) }

  context 'have no data in db' do
    it { expect(record.tweets_count).to eq 111.to_f }
  end

  context 'already have data in db' do
    it do
      described_class.new(project).call(
        date: Date.new(2018, 3, 21),
        metrics: {
          tweets_count: 333, favorites_count: 0, twitters_count: 0,
          coverage: 0, replies_count: 0, retweets_count: 0
        }
      )

      expect(record.tweets_count).to eq 185.to_f
    end
  end

  after { project.delete }
end
