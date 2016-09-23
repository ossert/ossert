require "ossert/version"
require 'gems'
require 'sequel'
# interesting... https://rubygems.org/pages/data
# https://github.com/xmisao/bestgems.org/wiki/BestGems-API-v1-Specification
# http://bestgems.org/gems/gon
require 'active_support/all' # remove later, we use only quarters and index_by here
require 'json'
require 'oj'

require 'weakref'
require "ossert/saveable"
require "ossert/fetch"
require "ossert/reports"
require "ossert/reference"
require "ossert/classifiers"
require "ossert/project_decorator"
require 'octokit'

module Ossert
  def rom
    return @rom if defined? @rom
    conf = ROM::Configuration.new(:sql, ENV.fetch("DATABASE_URL"))
    conf.register_relation(Projects)
    conf.register_relation(Exceptions)
    @rom = ROM.container(conf)
  end
  module_function :rom

  class Project
    attr_accessor :name, :gh_alias, :rg_alias,
                  :community, :agility, :reference,
                  :meta

    def analyze_by_growing_classifier
      raise unless Classifiers::Growing.current.ready?
      Classifiers::Growing.current.check(self)
    end

    def analyze_by_decisision_tree
      raise unless Classifiers::DecisionTree.current.ready?
      Classifiers::DecisionTree.current.check(self)
    end

    def initialize(name, gh_alias = nil, rg_alias = nil, reference = nil, meta: nil, agility: nil, community: nil)
      @name = name.dup
      @gh_alias = gh_alias
      @rg_alias = (rg_alias || name).dup
      @agility = agility || Agility.new
      @community = community || Community.new
      @reference = reference.dup
      @meta = meta || {
        homepage_url: nil,
        docs_url: nil,
        wiki_url: nil,
        source_url: nil,
        issue_tracker_url: nil,
        mailing_list_url: nil,
        authors: nil,
        top_10_contributors: Array.new,
        description: nil,
        current_version: nil,
        rubygems_url: nil,
        github_url: nil,
      }
    end

    def repo
      ProjectRepo.new(Ossert.rom)
    end

    def meta_to_json
      JSON.generate(meta)
    end

    def dump_meta # dump attribute
      current_repo = repo
      saved = current_repo[name]
      if saved
        current_repo.update(
          name,
          meta_data: meta_to_json,
        )
      else
        raise 'Not saved yet, sorry!'
      end
    end

    def dump
      current_repo = repo
      saved = current_repo[name]
      if saved
        current_repo.update(
          name,
          name: name,
          github_name: gh_alias,
          rubygems_name: rg_alias,
          reference: reference,
          meta_data: meta_to_json,
          agility_total_data: agility.total.to_json,
          agility_quarters_data: agility.quarters.to_json,
          community_total_data: community.total.to_json,
          community_quarters_data: community.quarters.to_json
        )
      else
        current_repo.create(
          name: name,
          github_name: gh_alias,
          rubygems_name: rg_alias,
          reference: reference,
          meta_data: meta_to_json,
          agility_total_data: agility.total.to_json,
          agility_quarters_data: agility.quarters.to_json,
          community_total_data: community.total.to_json,
          community_quarters_data: community.quarters.to_json
        )
      end
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

      def fetch_all(name, reference = Ossert::Saveable::UNUSED_REFERENCE)
        name = name.dup
        reference = reference.dup
        name_exception = ExceptionsRepo.new(Ossert.rom)[name]
        if name_exception
          prj = new(name, name_exception.github_name, name, reference)
        else
          prj = new(name, nil, name, reference)
        end
        Ossert::Fetch.all prj
        prj.dump
        nil
      end

      def filename
        "projects"
      end

      def projects
        @projects ||= []
      end

      def projects_by_reference
        load_referenced.group_by { |prj| prj.reference }
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
      if value.is_a? String
        # DateTime.parse(value).beginning_of_quarter.to_i
        DateTime.new(*value.split('-'.freeze).map(&:to_i)).beginning_of_quarter.to_i
      else
        Time.at(value).to_date.to_time(:utc).beginning_of_quarter.to_i
      end
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

    def reverse_each_sorted
      quarters.sort.reverse.map do |key,value|
        yield(key, value)
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
          :users_commenting_pr_count, :stargazers_count,
          :forks_count,
          # :contributors_count,
          :users_involved_count, :users_involved_no_stars_count,
          :download_divergence, :total_downloads, :delta_downloads
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
                  :users_involved,
                  :download_divergence, :total_downloads, :delta_downloads

    [:users_creating_issues, :users_commenting_issues, :users_creating_pr,
    :users_commenting_pr, :contributors, :stargazers, :forks,
    :users_involved].each do |metric|
      define_method("#{metric}_count") { send(metric).count }
    end

    def users_involved_no_stars_count
      (users_involved - stargazers).count
    end

    NON_SET_VARS = %w(download_divergence total_downloads delta_downloads)

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

  class AgilityTotalStat
    class << self
      attr_accessor :attributes

      def attr_accessor *attrs
        self.attributes = Array attrs
        super
      end

      def metrics
        [
          :issues_active_percent, :issues_non_owner_percent, :issues_with_contrib_comments_percent, :issues_all_count,
          :issues_closed_percent,
          :pr_active_percent, :pr_non_owner_percent, :pr_with_contrib_comments_percent, :pr_all_count,
          :pr_closed_percent,
          :issues_processed_in_avg, :pr_processed_in_avg,
          :first_pr_date_int, :last_pr_date_int, :first_issue_date_int, :last_issue_date_int, :last_release_date_int,
          :releases_count, :commits_count_since_last_release_count,
          :last_year_commits, :life_period, :last_changed,
          :stale_branches_count
        ]
      end
    end

    # #### Stats, total for all time
    # - Merged PRs
    # - Opened non-author Issues, "with author comments" and total count
    # - Issues "no:assignee" "no:milestone" to total count
    # - Amount of changes each quarter (Graph? -> Later)
    attr_accessor :issues_open, :issues_closed, :issues_owner, :issues_non_owner, :issues_with_contrib_comments, :issues_total,
                  :issues_processed_in_avg,
                  :pr_open, :pr_merged, :pr_closed, :pr_owner, :pr_non_owner, :pr_with_contrib_comments, :pr_total,
                  :pr_processed_in_avg,
                  :first_pr_date, :last_pr_date, :first_issue_date, :last_issue_date,
                  :releases_total_gh, :releases_total_rg, :last_release_date, :commits_count_since_last_release,
                  :last_year_commits, :stale_branches, :branches

    NON_SET_VARS = %w(first_pr_date last_pr_date first_issue_date last_issue_date last_release_date
                      commits_count_since_last_release last_year_commits issues_processed_in_avg pr_processed_in_avg)
    [
      :issues_closed, :issues_active, :issues_non_owner, :issues_with_contrib_comments,
      :pr_closed, :pr_active, :pr_non_owner, :pr_with_contrib_comments,
    ].each do |metric|
      type = metric.to_s.split('_').first
      define_method("#{metric}_percent") do
        value = public_send(metric)
        total_count = public_send("#{type}_all").count
        return 0 if total_count.zero?
        ((value.count.to_d / total_count.to_d) * 100).round(2)
      end
    end

    [
      :first_pr_date, :last_pr_date, :first_issue_date, :last_issue_date, :last_release_date,
    ].each do |metric|
      define_method("#{metric}_int") { public_send(metric).to_i }
    end

    [:issues_all, :pr_all, :stale_branches].each do |metric|
      define_method("#{metric}_count") { public_send(metric).count }
    end

    def commits_count_since_last_release_count
      commits_count_since_last_release.is_a?(Set) ? 0 : commits_count_since_last_release
    end

    def issues_active
      issues_open - issues_closed
    end

    def issues_all
      issues_open + issues_closed
    end

    def pr_active
      pr_open - pr_closed
    end

    def pr_all
      pr_open + pr_closed
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

  class AgilityQuarterStat
    class << self
      attr_accessor :attributes

      def attr_accessor *attrs
        self.attributes = Array attrs
        super
      end

      def metrics
        [
          # :issues_active_count, :issues_closed_count,
          # :pr_active_count, :pr_closed_count,
          :issues_processed_in_avg, :pr_processed_in_avg,
          :issues_active_percent, :issues_closed_percent, :issues_all_count, :issues_actual_count,
          :pr_active_percent, :pr_closed_percent, :pr_all_count, :pr_actual_count,
          :releases_count, :commits
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
    attr_accessor :issues_open, :issues_closed, :issues_total, :issues_actual,
                  :pr_open, :pr_merged, :pr_closed, :pr_total, :pr_actual,
                  :pr_processed_in_days,
                  :releases,
                  :releases_total_gh, :branches, :releases_total_rg, :commits,
                  :issues_processed_in_days

    VARS_INITIALIZE = {
      issues_open: Set,
      issues_closed: Set,
      issues_total: Set,
      issues_actual: Set,
      pr_open: Set,
      pr_merged: Set,
      pr_closed: Set,
      pr_total: Set,
      pr_actual: Set,
      releases: Set,
      releases_total_gh: Set,
      branches: Set,
      releases_total_rg: Set
    }
    # NON_SET_VARS = %w()

    [
      :issues_active, :issues_closed,
      :pr_active, :pr_closed, :pr_merged
    ].each do |metric|
      type = metric.to_s.split('_').first
      define_method("#{metric}_percent") do
        value = public_send(metric)
        total_count = public_send("#{type}_all").count
        return 0 if total_count.zero?
        ((value.count.to_d / total_count.to_d) * 100).round(2)
      end
    end

    [:issues_active, :pr_active, :issues_closed, :issues_actual,
     :pr_closed, :issues_all, :pr_all, :pr_actual].each do |metric|
      define_method("#{metric}_count") { public_send(metric).count }
    end

    def issues_processed_in_avg
      values = issues_processed_in_days.to_a.sort
      if values.count.odd?
        values[values.count/2]
      elsif values.count.zero?
        0
      else
        ((values[values.count/2 - 1] + values[values.count/2]) / 2.0).to_i
      end
    end

    def pr_processed_in_avg
      values = pr_processed_in_days.to_a.sort
      if values.count.odd?
        values[values.count/2]
      elsif values.count.zero?
        0
      else
        ((values[values.count/2 - 1] + values[values.count/2]) / 2.0).to_i
      end
    end

    def issues_active
      (issues_open + issues_actual) - issues_closed
    end

    def issues_all
      issues_open + issues_closed + issues_actual
    end

    def pr_active
      (pr_open + pr_actual) - pr_closed
    end

    def pr_all
      pr_open + pr_closed + pr_actual
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
      self.class.metrics.map do |metric|
        value = public_send(metric).to_f
        metric.to_s =~ /percent/ ? value / 3.0 : value
      end
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
