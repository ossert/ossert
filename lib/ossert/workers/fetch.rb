module Ossert
  module Workers
    class Fetch
      include Sidekiq::Worker
      include Process
      sidekiq_options unique: :until_executed,
                      unique_expiration: 1.hour,
                      retry: 3

      def perform(name)
        pid = fork do
          Ossert::Project.fetch_all(name)
        end
        waitpid(pid)
      end
    end
  end
end
