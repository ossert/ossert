# frozen_string_literal: true

module Ossert
  module Workers
    class PartialFetch
      include Sidekiq::Worker
      include ForkProcessing
      sidekiq_options unique: :until_executed,
                      unique_expiration: 1.hour,
                      retry: 3

      def perform(fetcher_name, name, reference = Ossert::Saveable::UNUSED_REFERENCE)
        fetcher = Kernel.const_get("Ossert::Fetch::#{fetcher_name}")
        return unless fetcher

        logger.info "Fetching data for: '#{name}' (ref: #{reference}) only from #{fetcher_name}"
        process_in_fork do
          Ossert.init
          Ossert::Project.update_with_one_fetcher(fetcher, name, reference)
        end
      end
    end
  end
end
