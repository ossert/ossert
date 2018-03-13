# frozen_string_literal: true
module Ossert
  module Workers
    class NormalizatCalculations
      include Sidekiq::Worker
      include ForkProcessing
      sidekiq_options unique: :until_executed,
                      unique_expiration: 1.hour,
                      retry: 3

      def perform(name, reference = Ossert::Saveable::UNUSED_REFERENCE)
        logger.info "Fetching data for: '#{name}' (ref: #{reference})"
        process_in_fork do
          Ossert.init
          Ossert::Project.find_by_name(name)
        end
      end
    end
  end
end
