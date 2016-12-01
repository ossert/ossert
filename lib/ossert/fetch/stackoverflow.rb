module Ossert
  module Fetch
    class StackOverflow
      attr_reader :client, :project

      extend Forwardable
      def_delegators :project, :agility, :community, :meta

      BASE_URL = 'https://api.stackexchange.com/2.2/'
      SEARCH_URL = 'search/advanced'
      SEARCH_PARAMS = {
        site: :stackoverflow,
        tagged: 'ruby',
        filter: :total,
        key: ENV['SO_TOKEN']  # optional, but without it only 300 requests/day are available
      }.freeze

      def initialize(project)
        @client = SimpleClient.new(BASE_URL)
        @project = project
      end

      def process
        process_questions
      end

      private

      def fetch_questions
        @client.get(SEARCH_URL, SEARCH_PARAMS.merge(q: '"' + project.name + '"'))
      end

      def fetch_resolved_questions
        @client.get(SEARCH_URL, SEARCH_PARAMS.merge(q: '"' + project.name + '"', accepted: true))
      end

      def process_questions
        community.total.questions_count = fetch_questions[:total]
        community.total.questions_resolved_count = fetch_resolved_questions[:total]
      end
    end
  end
end