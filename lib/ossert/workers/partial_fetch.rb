# frozen_string_literal: true
module Ossert
  module Workers
    class PartialFetch
      include Sidekiq::Worker
      include Process
      sidekiq_options unique: :until_executed,
                      unique_expiration: 1.hour,
                      retry: 3

      def perform(fetcher_name, name, reference = Ossert::Saveable::UNUSED_REFERENCE)
        return unless fetcher = Kernel.const_get("Ossert::Fetch::#{fetcher_name}")
        puts "Fetching data for: '#{name}' (ref: #{reference}) only from #{fetcher_name}"
        pid = fork do
          Ossert.init
          Ossert::Project.update_with_one_fetcher(fetcher, name, reference)
        end
        waitpid(pid)
      end
    end
  end
end
