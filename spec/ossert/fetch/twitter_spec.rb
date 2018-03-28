# frozen_string_literal: true

require 'spec_helper'

describe Ossert::Fetch::Twitter do
  describe 'process' do
    let(:credentials) { Ossert::Twitter::Credentials.default }
    let(:fetcher) { described_class.new(project, credentials) }
    let(:project) { Ossert::Project.load_by_name('sidekiq') }
    let(:date) { Date.today }
    let(:metrics) do
      ::TwitterMetrics.where(project_id: project.id, date: date.monday).first
    end

    before do
      NameException.create(name: 'sidekiq', github_name: 'mperham/sidekiq')
      Ossert::Project.find_by_name('sidekiq').dump
    end

    it 'runs successfully and returns twitter metrics (for a while)' do
      VCR.use_cassette('twitter/200/valid') { fetcher.process }

      expect(metrics).to have_attributes(
        tweets_count: 13.0,
        favorites_count: 13.0,
        replies_count: 5.0,
        retweets_count: 6.0,
        coverage: 15_145.0,
        twitters_count: 12.0
      )
    end

    after { ::Project.find(name: 'sidekiq').delete }
  end
end
