# frozen_string_literal: true
module Ossert
  module Fetch
    class SimpleClient; end
    # SimpleClient override to provide OAuth capabilities
    class RedditSimpleClient < SimpleClient
      attr_reader :expiration

      # Authorization URL for getting access token
      AUTH_URL = 'https://www.reddit.com/api/v1/access_token'.freeze

      # Public: Method override, introduces expiration instance variable
      # Returns nothing
      def initialize(api_endpoint, type = nil)
        super
        @expiration = Time.now
      end

      class FailedAuthorization < StandardError; end

      # Public: Authorize client for further requests
      # Returns nothing.
      def authorize
        prepare_headers
        response = agent.post(AUTH_URL, grant_type: 'client_credentials')
        raise FailedAuthorization unless response.status == 200
        body = JSON.parse(response.body)
        @expiration = Time.now + body['expires_in']
        agent.headers['Authorization'] = "bearer #{body['access_token']}"
      end

      private

      # Internal: Update agent headers according to Reddit API guidelines
      # Returns nothing.
      def prepare_headers
        agent.basic_auth ENV.fetch('REDDIT_APP_ID'), ENV.fetch('REDDIT_APP_SECRET')
        agent.headers["User-Agent"] = "script:#{ENV.fetch('REDDIT_APP_ID')}:#{Ossert::VERSION}"
      end
    end

    # Class implementing `Reddit` crawler.
    class Reddit
      attr_reader :client, :project

      # for delegators
      extend Forwardable

      # @!method community
      # @see Project#community
      # @return (see Project#community)
      def_delegators :project, :community

      # Common OAuth URL for all Reddit API queries
      BASE_URL = 'https://oauth.reddit.com/'.freeze

      # A path for searching of posts
      SEARCH_URL = 'search'.freeze

      # List of queried subreddits with their id's in base-10 format
      SUBREDDITS = [
        { id: '5360722', name: 'ruby_infosec' },
        { id: '4595620', name: 'rubyonrails' },
        { id: '4595027', name: 'rails' },
        { id: '4594393', name: 'ruby' }
      ].freeze

      # A template set of parameters for every query to Reddit API.
      SEARCH_PARAMS = {
        limit: 100,
        sort: :new,
        syntax: 'cloudsearch'
      }.freeze

      # Create Reddit fetcher
      # project - Ossert::Project instance
      def initialize(project)
        @client = RedditSimpleClient.new(BASE_URL)
        @project = project
        @cmn_params = SEARCH_PARAMS.merge(
          q: '(and '\
             "(or #{SUBREDDITS.map { |sr| "sr_id:'#{sr[:id]}'" }.join(' ')}) "\
             "(or title:'\"#{project.name}\"' selftext:'\"#{project.name}\"')"\
             ')'
        )
      end

      # Public: Trigger fetching
      # Starts fetching of the data from Reddit.
      # *NOTE:* it mutates the project object passed during the initialisation.
      # Returns nothing.
      def process
        resp = {}
        loop do
          resp = fetch_posts(after: resp[:after])[:data]
          resp[:children].each { |post| process_post(post[:data]) }
          break if resp[:after].nil?
        end
      end

      private

      # Internal: Fetch one page of posts, checks authorization first
      # params - Hash with additional search params
      # Returns Hash with Reddit response
      def fetch_posts(params = {})
        @client.authorize if @client.expiration <= Time.now
        @client.get(SEARCH_URL, @cmn_params.merge(params))
      end

      # Processes post data, updates project stats
      # post - Hash with Reddit data for project
      # *NOTE:* it mutates the project object passed during the initialisation.
      # Returns nothing
      def process_post(post)
        quarter = community.quarters[post[:created_utc]]

        [community.total, quarter].each do |collection|
          idx = collection.posts.index(post[:id]) || collection.posts.length
          collection.posts[idx] = post[:id]
          collection.comments[idx] = post[:num_comments]
          collection.post_score[idx] = post[:score]
          collection.authors << post[:author]
        end
      end
    end
  end
end
