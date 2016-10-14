module Ossert
  module Stats
    class CommunityTotal
      class << self
        attr_accessor :attributes

        def attr_accessor *attrs
          self.attributes = Array attrs
          super
        end

        def metrics
          [
            :users_creating_issues_count, :users_commenting_issues_count, :users_creating_pr_count,
            :users_commenting_pr_count,
            :contributors_count, :watchers_count, :stargazers_count,
            :forks_count,
            :users_involved_count,
            :users_involved_no_stars_count,
            :total_downloads
          ]
        end
      end
      # #### Stats, total for all time
      # - Popularity Rating (https://www.ruby-toolbox.com/projects/delayed_job/popularity)
      attr_accessor :users_creating_issues, :users_commenting_issues, :users_creating_pr, :users_commenting_pr,
                    :contributors, :watchers, :stargazers, :forks,
                    :owners_github, :owners_rubygems, :users_involved,
                    :total_downloads, :delta_downloads

      [:users_creating_issues, :users_commenting_issues, :users_creating_pr,
      :users_commenting_pr, :contributors, :watchers, :stargazers, :forks,
      :users_involved].each do |metric|
        define_method("#{metric}_count") { send(metric).count }
      end

      def users_involved_no_stars_count
        (users_involved - stargazers).count
      end

      NON_SET_VARS = %w(total_downloads delta_downloads)

      # sets of users
      def initialize
        self.class.attributes.each do |var|
          next if NON_SET_VARS.include?(var.to_s)
          send "#{var}=", Set.new
        end
      end

      def metric_values
        self.class.metrics.map { |metric| public_send(metric).to_i }
      end

      def metrics_to_hash
        self.class.metrics.each_with_object({}) do |var, result|
          value = send(var)
          if value.is_a? Set
            result[var] = value.to_a
          else
            result[var] = value
          end
        end
      end

      def to_hash
        self.class.attributes.each_with_object({}) do |var, result|
          value = send(var)
          if value.is_a? Set
            result[var] = value.to_a
          else
            result[var] = value
          end
        end
      end

      def to_json
        JSON.generate(to_hash)
      end
    end
  end
end
