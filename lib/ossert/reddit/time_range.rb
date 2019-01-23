# frozen_string_literal: true

module Ossert
  module Reddit
    # Faster date range generation
    class TimeRange
      attr_reader :after, :before

      def self.exhaustive
        new(Time.at(0), Time.new)
      end

      def initialize(after, before)
        @after = after.to_i
        @before = before.to_i
      end
    end
  end
end
