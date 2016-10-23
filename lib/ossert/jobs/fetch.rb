module Ossert
  module Jobs
    class Fetch
      include SuckerPunch::Job

      def perform(name)
        Ossert::Project.fetch_all(name)
      end
    end
  end
end
