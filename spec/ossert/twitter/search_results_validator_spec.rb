# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe Ossert::Twitter::SearchResultsValidator do
  describe 'call!' do
    let(:validator) { described_class }

    context 'valid twitter json' do
      let(:json) { JSON.parse(File.read('spec/fixtures/twitter/valid.json')) }

      it { expect { validator.call!(json) }.not_to raise_error }
    end

    context 'invalid json' do
      let(:json) { { 'statuses': [{ 'empty': 'data' }] } }

      it { expect { validator.call!(json) }.to raise_error JSON::Schema::ValidationError }
    end
  end
end
