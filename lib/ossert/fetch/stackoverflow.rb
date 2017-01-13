# frozen_string_literal: true
module Ossert
  module Fetch
    # Class implementing `StackOverflow` crawler.
    class StackOverflow
      attr_reader :client, :project

      # @!attribute [r] client
      # a trivial client for fetching web API
      # @return [SimpleClient] instance of the prepared web page fetcher

      # @!attribute [r] project
      # project which will be filled during the processing step of the fetcher
      # @return [Ossert::Project] project filled by this fetcher

      # for delegators
      extend Forwardable

      # @!method community
      # @see Project#community
      # @return (see Project#community)
      def_delegators :project, :community

      # Common URL for all StackExchange related queries
      BASE_URL = 'https://api.stackexchange.com/2.2/'

      # A path for searching of questions
      SEARCH_URL = 'search/advanced'

      # A template set of parameters for every query to StackExchange.
      SEARCH_PARAMS = {
        site: :stackoverflow,
        tagged: 'ruby',
        pagesize: 100,
        order: :asc,
        sort: :creation
      }.freeze

      # Maximum number of pages to be fetched for a single project
      MAX_PAGES = 50

      # Create StackOverflow fetcher
      # @param project [Project] a project to fill
      def initialize(project)
        @client = SimpleClient.new(BASE_URL)
        @project = project
        @cmn_params = SEARCH_PARAMS.merge(q: "\"#{project.name}\"")

        if (token = Utils::KeysStorage::SO.call).present?
          @cmn_params[:key] = token
        end
      end

      # Trigger fetching
      #
      # Starts fetching of the data from StackOverflow.
      # *NOTE:* it mutates the project object passed during the initialisation.
      # @return [nil] Not specified.
      def process
        process_questions_total
        process_last_year_questions
      end

      private

      # Fetch all questions
      # @param params [Hash<String, String>] special params for the search
      # @return [Hash<Symbol, Hash>] a response from SO
      def fetch_questions(params = {})
        @client.get(SEARCH_URL, @cmn_params.merge(params))
      end

      # Fetch resolved questions
      # @param params [Hash<String, String>] special params for the search
      # @return [Hash<Symbol, Hash>] a response from SO
      def fetch_resolved_questions(params = {})
        fetch_questions(params.merge(accepted: true))
      end

      # Fetch several pages of questions seamlessly
      # @param params [Hash<String, String>] special params for the search
      # @yieldparam question [Hash<Symbol, Hash>] one of the fetched questions
      # @return [nil] Not specified
      def fetch_questions_batch(params = {})
        page = 1
        resp = fetch_questions(params.merge(page: page))
        while resp[:items].length.positive? && page < MAX_PAGES
          resp[:items].each { |question| yield question }
          page += 1
          resp = fetch_questions(params.merge(page: page))
        end
      end

      # Process total stats
      #
      # Process aggregated data for the project on StackOverflow.
      # @return [nil] Not specified.
      def process_questions_total
        community.total.questions_count = fetch_questions(filter: :total)[:total]
        community.total.questions_resolved_count = fetch_resolved_questions(filter: :total)[:total]
        if last_question = fetch_questions(order: :desc, pagesize: 5).dig(:items, 0)
          community.total.last_question_date = last_question[:creation_date]
        end
      end

      # Process last year stats
      #
      # Process aggregated data for the project on StackOverflow
      # for the last 5 quarters.
      # @return [nil] Not specified.
      def process_last_year_questions
        start_date = (Time.now.utc - 1.year).beginning_of_quarter.to_i

        fetch_questions_batch(fromdate: start_date) do |question|
          quarter = community.quarters[question[:creation_date]]

          quarter.questions << question[:question_id]
          if question[:is_answered]
            quarter.questions_resolved << question[:question_id]
          end
          if question[:owner][:user_id] && !quarter.questioners.include?(question[:owner][:user_id])
            quarter.questioners << question[:owner][:user_id]
            quarter.questioner_rep << question[:owner][:reputation] # TODO: see the last issue in docs/so-fetcher.md
          end
          quarter.question_view << question[:view_count]
          quarter.question_score << question[:score]
          quarter.answers << question[:answer_count]
        end
      end
    end
  end
end
