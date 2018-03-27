# frozen_string_literal: true

require 'spec_helper'

describe Ossert::Twitter::Metrics do
  describe 'new' do
    let(:metrics) { described_class.new }

    it 'intializes with zero values' do
      metrics.each do |metric_value|
        expect(metric_value).to eq 0
      end
    end
  end
end
