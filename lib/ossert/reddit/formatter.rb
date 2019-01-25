# frozen_string_literal: true

module Ossert
  module Reddit
    # Format raw data into metrics
    class Formatter
      FIELDS = %i[comment_scores
                  commentators
                  comments
                  submission_comment_numbers
                  submission_scores
                  submitters
                  submissions
                  users].freeze

      attr_accessor(*FIELDS)

      def initialize(submissions, comments)
        @submitters = Set.new

        @submissions = []
        @submission_comment_numbers = []
        @submission_scores = []

        @commentators = Set.new
        @comments = []
        @comment_scores = []

        @users = Set.new

        parse_data(submissions, comments)
      end

      def commentators
        @commentators.to_a
      end

      def submitters
        @submitters.to_a
      end

      def users
        @users.to_a
      end

      private

      def parse_data(submissions, comments)
        parse_submissions(submissions)
        parse_comments(comments)
        @users = @submitters + @commentators
      end

      def parse_submissions(data)
        data.each do |hash|
          @submissions << hash[:id]
          @submission_comment_numbers << hash[:num_comments]
          @submission_scores << hash[:score]
          @submitters << hash[:author]
        end
      end

      def parse_comments(data)
        data.each do |hash|
          @commentators << hash[:author]
          @comments << hash[:id]
          @comment_scores << hash[:score]
        end
      end
    end
  end
end
