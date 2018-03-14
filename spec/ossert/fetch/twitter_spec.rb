# frozen_string_literal: true

require 'spec_helper'

describe Ossert::Fetch::Twitter do
  describe 'process' do
    let(:fetcher) { described_class.new(project) }
    let(:project) { double(github_alias: 'mperham/sidekiq') }

    it 'runs successfully and returns twitter metrics (for a while)' do
      VCR.use_cassette('twitter/200/valid') do
        # will have more complex tests here, when begin write metrics to db
        expect(fetcher.process).to be_a(Ossert::Twitter::Metrics)
      end
    end
  end
end
