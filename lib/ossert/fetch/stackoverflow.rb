module Ossert
  module Fetch
    class StackOverflow
      attr_reader :client, :project
 
      extend Forwardable
      def_delegators :project, :agility, :community, :meta
 
      PAGES_LIMIT = 10 # to be adjusted
      BASE_URL = 'https://api.stackexchange.com/2.2/'
      SEARCH_URL = 'search'
      SEARCH_PARAMS = {
        order: :desc,
        sort: :creation,
        site: :stackoverflow,
        tagged: 'ruby;ruby-on-rails',
        pagesize: 100,
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
        no_data = false
        (1..PAGES_LIMIT).reduce([]) do |acc, page|
          if no_data 
            acc
          else
            res = @client.get(SEARCH_URL, SEARCH_PARAMS.merge(intitle: project.name, page: page))  
            no_data = !res[:items].count # I faced with a bug when has_more is false, but it was clearly wrong
            acc + res[:items]
          end
        end 
      end

      def process_questions 
        community.total.questions_count = fetch_questions.count
      end
    end
  end
end       