# frozen_string_literal: true
module Ossert
  module Workers
    class RefreshFetch
      include Sidekiq::Worker
      include ForkProcessing
      sidekiq_options unique: :until_executed,
                      unique_expiration: 1.hour,
                      retry: 3

      def perform
        process_in_fork do
          Ossert.init
          ::Project.select(:name, :reference).where('updated_at < ?', 1.month.ago)
                   .order(:updated_at)
                   .paged_each do |project|
            Ossert::Workers::Fetch.perform_async(project.name, project.reference)
          end
        end
      end
    end
  end
end
