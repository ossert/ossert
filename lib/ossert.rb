require "ossert/version"
require 'gems'
# interesting... https://rubygems.org/pages/data
# https://github.com/xmisao/bestgems.org/wiki/BestGems-API-v1-Specification
# http://bestgems.org/gems/gon
require 'active_support/all' # remove later, we use only quarters and index_by here
require 'json'
require 'oj'

require "ossert/fetch"
require "ossert/reports"
require "ossert/reference"
require 'octokit'

# TODO: convert data to CSV

module Ossert
  class Project
    attr_accessor :name, :gh_alias, :rg_alias,
                  :community, :agility, :reference

    def analyze_by_growing_classifier
      raise unless Reference::Base.growing_classifier_ready?
      Reference::Base.check_against_growing_classifier(self)
    end

    def analyze
      raise unless Reference::Base.decision_tree_ready?

      agility.total_prediction =
        Reference::Base.agility_total_dec_tree.predict(agility.total.metric_values)
      agility.quarter_prediction =
        Reference::Base.agility_quarters_dec_tree.predict(agility.quarters.last_year_data)
      community.total_prediction =
        Reference::Base.community_total_dec_tree.predict(community.total.metric_values)
      community.quarter_prediction =
        Reference::Base.community_quarters_dec_tree.predict(community.quarters.last_year_data)

      {
        agility: {
          total: agility.total_prediction,
          last_year: agility.quarter_prediction
        },
        community: {
          total: community.total_prediction,
          last_year: community.quarter_prediction
        }
      }
    end

    def initialize(name, gh_alias = nil, rg_alias = nil, reference = nil)
      @name = name
      @gh_alias = gh_alias
      @rg_alias = rg_alias || name
      @agility = Agility.new
      @community = Community.new
      @reference = reference
      self.class.projects << self
    end

    class Agility
      attr_accessor :quarters, :total, :total_prediction, :quarter_prediction

      def initialize
        @quarters = QuartersStore.new(AgilityQuarterStat)
        @total = AgilityTotalStat.new
      end
    end

    class Community
      attr_accessor :quarters, :total, :total_prediction, :quarter_prediction

      def initialize
        @quarters = QuartersStore.new(CommunityQuarterStat)
        @total = CommunityTotalStat.new
      end
    end

    class << self
      def projects
        @projects ||= []
      end

      def projects_by_reference
        projects.group_by { |prj| prj.reference }
      end

      # FIXME: Use normal backend, such as Postgres
      def load
        if File.exists?('data/projects.json')
          @projects = Oj.load File.read('data/projects.json')
        end

        self
      end

      def dump
        existance_backup("data/projects.json")
        File.open("data/projects.json","w") do |f|
          f.write(Oj.dump(projects))
        end
      end

      def existance_backup(filename)
        return unless File.exists?(filename)
        FileUtils.cp(filename, "#{filename}.#{Time.now.strftime('%d%m%Y-%H%M%S.%L')}")
      end
    end
  end

  class QuartersStore
    attr_reader :quarters, :stat_klass, :start_date, :end_date

    def initialize(stat_klass)
      @stat_klass = stat_klass
      @quarters = Hash.new
    end

    def find_or_create(date)
      quarters[date_to_start(date)] ||= stat_klass.new
    end
    alias_method :[], :find_or_create

    def date_to_start(value)
      Time.at(value.to_i).beginning_of_quarter.to_i
    end

    def preview
      quarters.sort.map { |date_i, value| [Time.at(date_i), value] }.to_h
    end

    def last_year_data
      quarters.sort.last(4).map { |_, quarter| quarter.metric_values }.transpose.map {|x| x.reduce(:+)}
    end

    def last_year_as_hash
      Hash[stat_klass.metrics.zip(last_year_data)]
    end

    def fullfill!
      if quarters.empty?
        @start_date = Time.now
        @end_date = Time.now
        return
      end

      sorted_quarters = quarters.keys.sort
      @start_date = Time.at sorted_quarters.first
      @end_date = Time.at sorted_quarters.last
      period = start_date + 93.days
      while period < end_date
        find_or_create(period)
        period = period + 93.days
      end
    end

    def each_sorted
      quarters.sort.map do |key,value|
        yield(key, value)
      end
    end
  end

  class CommunityTotalStat
    class << self
      attr_accessor :attributes

      def attr_accessor *attrs
        self.attributes = Array attrs
        super
      end

      def metrics
        [
          :users_creating_issues_count, :users_commenting_issues_count, :users_creating_pr_count,
          :users_commenting_pr_count, :contributors_count, :watchers_count, #:stargazers_count,
          :forks_count,
          :users_involved_count#, :users_involved_no_stars_count
        ]
      end
    end
    # #### Stats, total for all time
    # - Popularity Rating (https://www.ruby-toolbox.com/projects/delayed_job/popularity)
    attr_accessor :users_creating_issues, :users_commenting_issues, :users_creating_pr, :users_commenting_pr,
                  :contributors, :watchers, :stargazers, :forks,
                  :owners_github, :owners_rubygems, :users_involved

    [:users_creating_issues, :users_commenting_issues, :users_creating_pr,
    :users_commenting_pr, :contributors, :watchers, :stargazers, :forks,
    :users_involved].each do |metric|
      define_method("#{metric}_count") { send(metric).count }
    end

    def users_involved_no_stars_count
      (users_involved - stargazers).count
    end

    # sets of users
    def initialize
      self.class.attributes.each do |var|
        send "#{var}=", Set.new
      end
    end

    def metric_values
      self.class.metrics.map { |metric| public_send(metric).to_i }
    end
  end

  class CommunityQuarterStat
    class << self
      attr_accessor :attributes

      def attr_accessor *attrs
        self.attributes = Array attrs
        super
      end

      def metrics
        [
          :users_creating_issues_count, :users_commenting_issues_count, :users_creating_pr_count,
          :users_commenting_pr_count, :contributors_count, :stargazers_count,
          :forks_count,
          :users_involved_count, :users_involved_no_stars_count
        ]
      end
    end

    # #### Pulse, for last year/quarter/month (amount + delta from total)
    # - Users count writing issues
    # - Users count sent PR
    # - Contributors count
    # - Watchers, Stargazers, Forks
    # - Total users involved
    attr_accessor :users_creating_issues, :users_commenting_issues, :users_creating_pr, :users_commenting_pr,
                  :contributors, :stargazers, :forks, # NO DATES... FUUU... :watchers,
                  :users_involved

    [:users_creating_issues, :users_commenting_issues, :users_creating_pr,
    :users_commenting_pr, :contributors, :stargazers, :forks,
    :users_involved].each do |metric|
      define_method("#{metric}_count") { send(metric).count }
    end

    def users_involved_no_stars_count
      (users_involved - stargazers).count
    end

    # sets of users
    def initialize
      self.class.attributes.each do |var|
        send "#{var}=", Set.new
      end
    end

    def metric_values
      self.class.metrics.map { |metric| public_send(metric).to_i }
    end
  end

  class AgilityTotalStat
    class << self
      attr_accessor :attributes

      def attr_accessor *attrs
        self.attributes = Array attrs
        super
      end

      def metrics
        [
          :issues_open_percent, :issues_non_owner_percent, :issues_with_contrib_comments_percent, :issues_total_count,
          :pr_open_percent, :pr_non_owner_percent, :pr_with_contrib_comments_percent, :pr_total_count,
          :first_pr_date_int, :last_pr_date_int, :first_issue_date_int, :last_issue_date_int, :last_release_date_int,
          :releases_count, :commits_count_since_last_release_count,
          :last_year_commits, :total_downloads, :life_period, :last_changed
        ]
      end
    end
    # #### Stats, total for all time
    # - Merged PRs
    # - Opened non-author Issues, "with author comments" and total count
    # - Issues "no:assignee" "no:milestone" to total count
    # - Amount of changes each quarter (Graph? -> Later)
    attr_accessor :issues_open, :issues_closed, :issues_owner, :issues_non_owner, :issues_with_contrib_comments, :issues_total,
                  :pr_open, :pr_merged, :pr_closed, :pr_owner, :pr_non_owner, :pr_with_contrib_comments, :pr_total,
                  :first_pr_date, :last_pr_date, :first_issue_date, :last_issue_date,
                  :releases_total_gh, :releases_total_rg, :last_release_date, :commits_count_since_last_release,
                  :last_year_commits, :stale_branches, :branches, :total_downloads, :delta_downloads

    NON_SET_VARS = %w(first_pr_date last_pr_date first_issue_date last_issue_date last_release_date
                      commits_count_since_after_release total_downloads delta_downloads last_year_commits)
    [
      :issues_closed, :issues_open, :issues_non_owner, :issues_with_contrib_comments,
      :pr_closed, :pr_open, :pr_non_owner, :pr_with_contrib_comments,
    ].each do |metric|
      total = "#{metric.to_s.split('_').first}_total"
      define_method("#{metric}_percent") do
        total_count = public_send(total).count
        return 0 if total_count.zero?
        (public_send(metric).count.to_f / total_count.to_f) * 100
      end
    end

    [
      :first_pr_date, :last_pr_date, :first_issue_date, :last_issue_date, :last_release_date,
    ].each do |metric|
      define_method("#{metric}_int") { public_send(metric).to_i }
    end

    [:issues_total, :pr_total, :commits_count_since_last_release].each do |metric|
      define_method("#{metric}_count") { public_send(metric).count }
    end

    def last_changed
      if last_pr_date.presence && last_issue_date.presence
        [last_pr_date, last_issue_date].max.to_i
      else
        last_pr_date.presence || last_issue_date.presence || 10.years.ago
      end
    end

    def life_period
      last_change = if last_pr_date.presence && last_issue_date.presence
                      [last_pr_date, last_issue_date].max
                    else
                      last_pr_date.presence || last_issue_date.presence
                    end

      return 0 if last_change.nil?

      first_change = if first_pr_date.presence && first_issue_date.presence
                      [first_pr_date, first_issue_date].min
                    else
                      last_pr_date.presence || last_issue_date.presence
                    end

      return 0 if first_change.nil?

      (last_change - first_change).to_i
    end

    def releases_count
      [releases_total_rg.count, releases_total_gh.count].max
    end

    def initialize
      self.class.attributes.each do |var|
        next if NON_SET_VARS.include?(var.to_s)
        send "#{var}=", Set.new
      end
    end

    def metric_values
      self.class.metrics.map { |metric| public_send(metric).to_i }
    end
  end

  class AgilityQuarterStat
    class << self
      attr_accessor :attributes

      def attr_accessor *attrs
        self.attributes = Array attrs
        super
      end

      def metrics
        [
          :issues_open_percent, :issues_closed_percent, :issues_total_count,
          :pr_open_percent, :pr_closed_percent, :pr_total_count,
          :releases_count, :commits, :total_downloads, :download_divergence
        ]
      end
    end
    # #### Pulse, for last year/quarter/month (amount + delta from total)
    # - Opened and Closed Issues
    # - Opened and Merged PRs
    # - Releases Count
    # - Downloads divergence
    # - Downloads degradation per release ??
    # - Branches Count
    attr_accessor :issues_open, :issues_closed, :issues_total, :pr_open, :pr_merged, :pr_closed, :pr_total, :releases,
                  :releases_total_gh, :branches, :releases_total_rg, :commits,
                  :download_divergence, :total_downloads, :delta_downloads

    NON_SET_VARS = %w(download_divergence total_downloads delta_downloads commits)

    [
      :issues_open, :issues_closed,
      :pr_open, :pr_closed,
    ].each do |metric|
      total = "#{metric.to_s.split('_').first}_total"
      define_method("#{metric}_percent") do
        total_count = public_send(total).count
        return 0 if total_count.zero?
        (public_send(metric).count.to_f / total_count.to_f) * 100
      end
    end

    [:issues_total, :pr_total].each do |metric|
      define_method("#{metric}_count") { public_send(metric).count }
    end

    def releases_count
      [releases_total_rg.count, releases_total_gh.count].max
    end

    def initialize
      self.class.attributes.each do |var|
        next if NON_SET_VARS.include?(var.to_s)
        send "#{var}=", Set.new
      end
    end

    def metric_values
      self.class.metrics.map { |metric| public_send(metric).to_i }
    end
  end
end
