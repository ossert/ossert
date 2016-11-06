# frozen_string_literal: true
module Ossert
  module Workers
    class RefreshFetch
      include Sidekiq::Worker
      include Process
      sidekiq_options unique: :until_executed,
                      unique_expiration: 1.hour,
                      retry: 3

      def perform
        pid = fork do
          Ossert.init
          ::Project.select(:name).where('updated_at < ?', 1.week.ago).paged_each do |project|
            Ossert::Workers::Fetch.perform_async(project.name)
          end
        end
        waitpid(pid)
      end
    end
  end
end
