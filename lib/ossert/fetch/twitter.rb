# frozen_string_literal: true

require 'ossert/twitter'

module Ossert
  module Fetch
    # Fetches metrics of passed project from Twitter and stores them to db
    class Twitter
      attr_reader :project, :credentials

      def initialize(project, credentials)
        @project = project
        @credentials = credentials
      end

      def process
        raise ArgumentError if project.without_github_data?

        tweets = Ossert::Twitter::TweetsFetcher.new(project, credentials).call
        metrics = Ossert::Twitter::MetricsCollector.new(tweets).call

        Ossert::Twitter::MetricsUpdater
          .new(project)
          .call(date: Date.today, metrics: metrics)
      end
    end
  end
end
