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
        :users_involved, :questioners, :questions, :posts, :authors
      )

      define_percent(questions_resolved: :questions)

      define_average(:answers, :comments)

      define_median(:questioner_rep)

      define_sum(:question_view, :question_score, :post_score)

      def users_involved_no_stars_count
        (users_involved - stargazers).count
      end

      def total_downloads_count
        delta_downloads
      end

      def download_divergence
        (delta_downloads.to_f / (1 + total_downloads.to_f)) * 100.0
      end
    end
  end
end
