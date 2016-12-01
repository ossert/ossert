# frozen_string_literal: true
module Ossert
  module Stats
    class CommunityTotal < Base
      self.section = 'community'
      self.section_type = 'total'
      create_attributes_accessors

      define_percent(
        questions_resolved: :questions
      )

      define_counts(
        :users_creating_issues, :users_commenting_issues, :users_creating_pr,
        :users_commenting_pr, :contributors, :watchers, :stargazers, :forks,
        :users_involved, :dependants
      )

      def users_involved_no_stars_count
        (users_involved - stargazers).count
      end

      def total_downloads_count
        total_downloads
      end
    end
  end
end
