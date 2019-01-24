# frozen_string_literal: true

module Ossert
  module Fetch
    # Class implementing `Reddit` crawler.
    class Reddit
      attr_reader :client, :project

      # for delegators
      extend Forwardable
      def_delegators :project, :community

      def initialize(project)
        @project = project
        @raw_fetcher = Ossert::Reddit::RawFetcher.new
      end

      def process
        process_quarters
        process_total
      end

      private

      def process_quarters
        quartered_data.each do |quarter, data|
          community = @project.community.quarters[quarter]
          data = formatted(data[:submissions], data[:comments])

          fill_with_formatter(community, data)
        end
      end

      def process_total
        data = formatted(plain_data[:submissions], plain_data[:comments])
        community_total = @project.community.total

        fill_with_formatter(community_total, data)

        community_total.reddit_last_comment_date = last_comment['created_utc']
        community_total.reddit_last_submission_date =
          last_submission['created_utc']
      end

      def formatted(submissions, comments)
        Ossert::Reddit::Formatter.new(submissions, comments)
      end

      def fill_with_formatter(store, formatter)
        Ossert::Reddit::Formatter::FIELDS.each do |field|
          store.send("reddit_#{field}=", formatter.send(field))
        end
      end

      def plain_data
        name = @project.name
        range = Time.at(0)..Time.now

        @plain_data ||= {
          submissions: @raw_fetcher.submissions(name, range),
          comments: @raw_fetcher.comments(name, range)
        }
      end

      def last_submission
        plain_data[:submissions].first || {}
      end

      def last_comment
        plain_data[:comments].first || {}
      end

      def quartered_data
        @quartered_data ||= divide_plain_data_by_quarters
      end

      def divide_plain_data_by_quarters
        all_submissions = group_by_quater plain_data[:submissions]
        all_comments = group_by_quater plain_data[:comments]
        all_quarters = all_submissions.keys & all_comments.keys

        all_quarters.each_with_object({}) do |quarter, result|
          result[quarter] = { comments: all_comments[quarter] || [],
                              submissions: all_submissions[quarter] || [] }
        end
      end

      def group_by_quater(data)
        data.group_by do |item|
          Time.at(item['created_utc']).beginning_of_quarter.to_i
        end
      end
    end
  end
end
