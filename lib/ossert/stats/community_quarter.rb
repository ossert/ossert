# frozen_string_literal: true
module Ossert
  module Stats
    class CommunityQuarter < Base
      self.section = 'community'
      self.section_type = 'quarter'
      create_attributes_accessors

      define_counts(
        :users_creating_issues, :users_commenting_issues, :users_creating_pr,
        :users_commenting_pr, :contributors, :stargazers, :forks,
        :users_involved
      )

      def users_involved_no_stars_count
        (users_involved - stargazers).count
      end

      def total_downloads
        delta_downloads
      end
    end
  end
end
