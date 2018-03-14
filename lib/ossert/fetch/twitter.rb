# frozen_string_literal: true

require 'ossert/twitter'

module Ossert
  module Fetch
    # Fetches metrics of passed project from Twitter and stores them to db
    class Twitter
      attr_reader :project

      def initialize(project)
        @project = project
      end

      def process
        raise ArgumentError unless project.github_alias.present?

        # will obtain the most suitable credentials
        credentials = Ossert::Twitter::Credentials.default
        tweets = Ossert::Twitter::TweetsFetcher.new(project, credentials).call
        metrics = Ossert::Twitter::MetricsCollector.new(tweets).call

        # will store metrics to database
     end
    end
  end
end
