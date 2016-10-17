module Ossert
  module Stats
    class CommunityTotal < Base
      self.section = 'community'
      self.section_type = 'total'
      create_attributes_accessors

      [:users_creating_issues, :users_commenting_issues, :users_creating_pr,
      :users_commenting_pr, :contributors, :watchers, :stargazers, :forks,
      :users_involved].each do |metric|
        define_method("#{metric}_count") { send(metric).count }
      end

      def users_involved_no_stars_count
        (users_involved - stargazers).count
      end
    end
  end
end
