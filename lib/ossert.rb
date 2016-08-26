require "ossert/version"
require 'gems'
require 'sequel'
# interesting... https://rubygems.org/pages/data
# https://github.com/xmisao/bestgems.org/wiki/BestGems-API-v1-Specification
# http://bestgems.org/gems/gon
require 'active_support/all' # remove later, we use only quarters and index_by here
require 'json'
require 'oj'

require 'rom-repository'
require 'rom-sql'

require "ossert/saveable"
require "ossert/fetch"
require "ossert/reports"
require "ossert/reference"
require "ossert/classifiers"
require 'octokit'

module Ossert
  class Project
    attr_accessor :name, :gh_alias, :rg_alias,
                  :community, :agility, :reference

    def analyze_by_growing_classifier
      raise unless Classifiers::Growing.current.ready?
      Classifiers::Growing.current.check(self)
    end

    def analyze_by_decisision_tree
      raise unless Classifiers::DecisionTree.current.ready?
      Classifiers::DecisionTree.current.check(self)
    end

    def initialize(name, gh_alias = nil, rg_alias = nil, reference = nil, agility: nil, community: nil)
      @name = name
      @gh_alias = gh_alias
      @rg_alias = rg_alias || name
      @agility = agility || Agility.new
      @community = community || Community.new
      @reference = reference
      self.class.projects << self
    end

    class Agility
      attr_accessor :quarters, :total, :total_prediction, :quarter_prediction

      def initialize(quarters: nil, total: nil)
        @quarters = quarters || QuartersStore.new(AgilityQuarterStat)
        @total = total || AgilityTotalStat.new
      end
    end

    class Community
      attr_accessor :quarters, :total, :total_prediction, :quarter_prediction

      def initialize(quarters: nil, total: nil)
        @quarters = quarters || QuartersStore.new(CommunityQuarterStat)
        @total = total || CommunityTotalStat.new
      end
    end

    class << self
      include Ossert::Saveable

      def filename
        "projects"
      end

      def projects
        @projects ||= []
      end

      def projects_by_reference
        projects.group_by { |prj| prj.reference }
      end

      def read
        projects
      end

      def assign(saved_data)
        @projects = saved_data
      end
    end
  end

  class QuartersStore
    attr_reader :quarters, :stat_klass, :start_date, :end_date

    def initialize(stat_klass)
      @stat_klass = stat_klass
      @quarters = Hash.new
    end

    def fetch(date)
      quarters.fetch date_to_start(date)
    end

    def find_or_create(date)
      quarters[date_to_start(date)] ||= stat_klass.new
    end
    alias_method :[], :find_or_create

    def date_to_start(value)
      Time.at(value).to_date.to_time(:utc).beginning_of_quarter.to_i
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

    def to_json
      hash = quarters.each_with_object({}) do |(time, metrics), result|
        result[time] = metrics.to_hash
      end
      JSON.generate(hash)
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

    def life_period_months
      life_period / 1.month
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

  class AgilityQuarterStat
    class << self
      attr_accessor :attributes

      def attr_accessor *attrs
        self.attributes = Array attrs
        super
      end

      def metrics
        [
          :issues_open_count, :issues_closed_count,
          :pr_open_count, :pr_closed_count,
          :issues_open_percent, :issues_closed_percent, :issues_total_count,
          :pr_open_percent, :pr_closed_percent, :pr_total_count,
          :releases_count, :commits, :total_downloads, :download_divergence,
          :delta_downloads
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
    attr_accessor :issues_open, :issues_closed, :issues_total, :pr_open,
                  :pr_merged, :pr_closed, :pr_total, :releases,
                  :releases_total_gh, :branches, :releases_total_rg, :commits,
                  :download_divergence, :total_downloads, :delta_downloads

    VARS_INITIALIZE = {
      issues_open: Set,
      issues_closed: Set,
      issues_total: Set,
      pr_open: Set,
      pr_merged: Set,
      pr_closed: Set,
      pr_total: Set,
      releases: Set,
      releases_total_gh: Set,
      branches: Set,
      releases_total_rg: Set
    }
    # NON_SET_VARS = %w()

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

    [:issues_open, :pr_open, :issues_closed,
     :pr_closed, :issues_total, :pr_total].each do |metric|
      define_method("#{metric}_count") { public_send(metric).count }
    end

    def releases_count
      [releases_total_rg.count, releases_total_gh.count].max
    end

    def initialize
      VARS_INITIALIZE.each_pair do |var, type|
        send "#{var}=", type.new
      end
      # self.class.attributes.each do |var|
      #   next if NON_SET_VARS.include?(var.to_s)
      #   send "#{var}=", Set.new
      # end
    end

    def metric_values
      self.class.metrics.map { |metric| public_send(metric).to_i }
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
