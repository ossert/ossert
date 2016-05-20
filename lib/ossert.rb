require "ossert/version"
require "ossert/fetch"
require "ossert/reports"
require "ossert/reference"
require 'octokit'
require 'gems'
# interesting... https://rubygems.org/pages/data
# https://github.com/xmisao/bestgems.org/wiki/BestGems-API-v1-Specification
# http://bestgems.org/gems/gon
require 'active_support/all' # remove later, we use only quarters and index_by here
require 'json'
require 'oj'

# TODO: convert data to CSV

module Ossert
  class Project
    attr_accessor :name, :gh_alias, :rg_alias,
                  :community, :agility, :reference

    def analyze
      raise unless Reference::Base.decision_tree_ready?

      agility.total_prediction =
        Reference::Base.agility_total_dec_tree.predict(agility.total.values)
      agility.quarter_prediction =
        Reference::Base.agility_quarters_dec_tree.predict(agility.quarters.last_year_data)
      community.total_prediction =
        Reference::Base.community_total_dec_tree.predict(community.total.values)
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
      quarters.sort.last(4).map { |_, quarter| quarter.values }.transpose.map {|x| x.reduce(:+)}
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
    end
    # #### Stats, total for all time
    # - Users count writing issues
    # - Users count sent PR
    # - Contributors count
    # - Watchers, Stargazers, Forks
    # - Owners... (link Rubygems and Github by email)
    # - Popularity Rating (https://www.ruby-toolbox.com/projects/delayed_job/popularity)
    # - Total users involved
    attr_accessor :users_creating_issues, :users_commenting_issues, :users_creating_pr, :users_commenting_pr,
                  :contributors, :watchers, :stargazers, :forks,
                  :owners_github, :owners_rubygems, :users_involved

    # sets of users
    def initialize
      self.class.attributes.each do |var|
        send "#{var}=", Set.new
      end
    end

    def values
      self.class.attributes.map do |attr|
        val = send(attr)
        val.is_a?(Set) ? val.count : (val.to_i)
      end
    end
  end

  class CommunityQuarterStat
    class << self
      attr_accessor :attributes

      def attr_accessor *attrs
        self.attributes = Array attrs
        super
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

    # sets of users
    def initialize
      self.class.attributes.each do |var|
        send "#{var}=", Set.new
      end
    end

    def values
      self.class.attributes.map do |attr|
        val = send(attr)
        val.is_a?(Set) ? val.count : (val.to_i)
      end
    end
  end

  class AgilityTotalStat
    class << self
      attr_accessor :attributes

      def attr_accessor *attrs
        self.attributes = Array attrs
        super
      end
    end
    # #### Stats, total for all time
    # - Opened and Closed Issues
    # - Opened, Merged and Closed PRs
    # - PR with owner/contributors comments
    # - Opened non-author Issues, "with author comments" and total count
    # - Issues "no:assignee" "no:milestone" to total count
    # - Time since first/last PR and Issue
    # - Releases Count
    #   http://octokit.github.io/octokit.rb/Octokit/Client/Releases.html#releases-instance_method
    # - Last Release Date
    #   http://octokit.github.io/octokit.rb/Octokit/Client/Releases.html#latest_release-instance_method
    # - Commits count since last release
    #   http://octokit.github.io/octokit.rb/Octokit/Client/Commits.html#commits_since-instance_method
    # - Amount of changes each quarter (Graph? -> Later)
    # - Stale and Total branches count
    # - Total downloads
    attr_accessor :issues_open, :issues_closed, :issues_owner, :issues_non_owner, :issues_with_contrib_comments, :issues_total,
                  :pr_open, :pr_merged, :pr_closed, :pr_owner, :pr_non_owner, :pr_with_contrib_comments, :pr_total,
                  :first_pr_date, :last_pr_date, :first_issue_date, :last_issue_date,
                  :releases_total_gh, :releases_total_rg, :last_release_date, :commits_count_since_last_release,
                  :last_year_commits, :stale_branches, :branches, :total_downloads, :delta_downloads

    NON_SET_VARS = %w(first_pr_date last_pr_date first_issue_date last_issue_date last_release_date
                      commits_count_since_after_release total_downloads delta_downloads last_year_commits)

    def initialize
      self.class.attributes.each do |var|
        next if NON_SET_VARS.include?(var.to_s)
        send "#{var}=", Set.new
      end
    end

    def values
      self.class.attributes.map do |attr|
        val = send(attr)
        val.is_a?(Set) ? val.count : (val.to_i)
      end
    end
  end

  class AgilityQuarterStat
    class << self
      attr_accessor :attributes

      def attr_accessor *attrs
        self.attributes = Array attrs
        super
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
    def initialize
      self.class.attributes.each do |var|
        next if NON_SET_VARS.include?(var.to_s)
        send "#{var}=", Set.new
      end
    end

    def values
      self.class.attributes.map do |attr|
        val = send(attr)
        val.is_a?(Set) ? val.count : (val.to_i)
      end
    end
  end
end
