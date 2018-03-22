# frozen_string_literal: true

require 'spec_helper'

describe Ossert::Twitter::MetricsUpdater do
  let!(:project) { ::Project.create(name: 'pp', github_name: 'pp/pp', rubygems_name: 'pp', reference: 'ClassA') }
  let(:date) { Date.new(2018, 3, 20) }
  let(:record) { ::TwitterMetrics.where(date: date.monday, project_id: project.id).first }
  let(:metrics) { Ossert::Twitter::Metrics.new(tweets_count: 111) }

  before { described_class.new(project).call(date: date, metrics: metrics) }

  context 'have no data in db' do
    it do
      expect(record.tweets_count).to eq 111.to_f
    end
  end

  context 'already have data in db' do
    it do
      described_class.new(project).call(
        date: Date.new(2018, 3, 21),
        metrics: Ossert::Twitter::Metrics.new(tweets_count: 333)
      )

      expect(record.tweets_count).to eq 185.to_f
    end
  end

  after { project.delete }
end
