# frozen_string_literal: true
module Ossert
  module Fetch
    class SimpleClient; end
    class RedditSimpleClient < SimpleClient
      attr_reader :expiration
      AUTH_URL = 'https://www.reddit.com/api/v1/access_token'.freeze

      def initialize(api_endpoint, type = nil)
        super
        @expiration = Time.now
      end

      class FailedAuthorization < StandardError; end

      def authorize
        prepare_headers
        response = agent.post(AUTH_URL, grant_type: 'client_credentials')
        raise FailedAuthorization unless response.status == 200
        body = JSON.parse(response.body)
        @expiration = Time.now + body['expires_in']
        agent.headers['Authorization'] = "bearer #{body['access_token']}"
      end

      private

      def prepare_headers
        agent.basic_auth ENV.fetch('REDDIT_APP_ID'), ENV.fetch('REDDIT_APP_SECRET')
        agent.headers["User-Agent"] = "script:#{ENV.fetch('REDDIT_APP_ID')}:#{Ossert::VERSION}"
      end
    end

    class Reddit
      attr_reader :client, :project

      extend Forwardable

      def_delegators :project, :community

      BASE_URL = 'https://oauth.reddit.com/'.freeze

      SEARCH_URL = 'search'.freeze

      SUBREDDITS = [
        { id: '5360722', name: 'ruby_infosec' },
        { id: '4595620', name: 'rubyonrails' },
        { id: '4595027', name: 'rails' },
        { id: '4594393', name: 'ruby' }
      ].freeze

      SEARCH_PARAMS = {
        limit: 100,
        sort: :new,
        syntax: 'cloudsearch'
      }.freeze

      MAX_PAGES = 50

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

      def process
        resp = {}
        loop do
          resp = fetch_posts(after: resp[:after])[:data]
          resp[:children].each { |post| process_post(post[:data]) }
          break if resp[:after].nil?
        end
      end

      private

      def fetch_posts(params = {})
        @client.authorize if @client.expiration <= Time.now
        @client.get(SEARCH_URL, @cmn_params.merge(params))
      end

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
