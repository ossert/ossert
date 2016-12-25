# frozen_string_literal: true
module Ossert
  module Workers
    class PartialRefreshFetch
      include Sidekiq::Worker
      include ForkProcessing
      sidekiq_options unique: :until_executed,
                      unique_expiration: 1.hour,
                      retry: 3

      def perform(fetcher_name)
        process_in_fork do
          Ossert.init
          ::Project.select(:name, :reference).paged_each do |project|
            Ossert::Workers::PartialFetch.perform_async(fetcher_name, project.name, project.reference)
          end
        end
      end
    end
  end
end
