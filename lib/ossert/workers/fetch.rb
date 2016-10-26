module Ossert
  module Workers
    class Fetch
      include Sidekiq::Worker
      sidekiq_options unique: :until_executed,
                      unique_expiration: 1.hour,
                      retry: 3

      def perform(name)
        Ossert::Project.fetch_all(name)
      end
    end
  end
end
