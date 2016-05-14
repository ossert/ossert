module Ossert
  module Fetch
    class SimpleClient
      attr_reader :api_endpoint, :type

      def initialize(api_endpoint, type = nil)
        raise ArgumentError if !api_endpoint.start_with?('http') || !api_endpoint.end_with?('/')
        @api_endpoint = api_endpoint
        @type = type || 'json'
      end

      class NotFound < StandardError; end

      def get(path)
        raise ArgumentError unless path.end_with? type
        response = agent.get("#{api_endpoint}#{path.to_s}")
        case response.status
        when 404
          raise NotFound
        when 200
          JSON.parse(response.body)
        end
      end

      private

      def agent
        @agent ||= ::Faraday.new do |http|
          http.request :url_encoded
          http.adapter :net_http
        end
      end
    end

    class Rubygems
      # Agility
      # => Total
      #     :releases_total_rg
      #
      # => Quarter
      #     :releases_total_rg
      #
      attr_reader :client, :project

      def initialize(project)
        @client = SimpleClient.new("https://rubygems.org/api/v1/")
        @project = project
      end

      def releases
        @releases ||= client.get("versions/#{project.rg_alias}.json")
      end

      def process
        releases.each do |release|
          project.agility.total.releases_total_rg << release['number']
          project.agility.quarters[release['created_at'].to_datetime].releases_total_rg << release['number']
        end
      end
    end

    class Bestgems
      # Agility
      # => Total
      #     :total_downloads
      #
      # => Quarter
      #     :total_downloads, :download_divergence, :delta_downloads
      #
      attr_reader :client, :project

      def initialize(project)
        @client = SimpleClient.new("http://bestgems.org/api/v1/")
        @project = project
      end

      def total_downloads
        @total_downloads ||= client.get("gems/#{project.rg_alias}/total_downloads.json")
      end

      def daily_downloads
        @daily_downloads ||= client.get("gems/#{project.rg_alias}/daily_downloads.json")
      end

      def total_ranking
        @total_ranking ||= client.get("gems/#{project.rg_alias}/total_ranking.json")
      end

      def daily_ranking
        @daily_ranking ||= client.get("gems/#{project.rg_alias}/daily_ranking.json")
      end

      def process
        downloads_till_now = nil
        total_downloads.each do |total|
          downloads_till_now = total unless downloads_till_now
          downloads_saved = project.agility.quarters[total['date'].to_datetime].total_downloads.to_i
          project.agility.quarters[total['date'].to_datetime].total_downloads = [downloads_saved, total['total_downloads']].max
        end
        project.agility.total.total_downloads = downloads_till_now['total_downloads']

        daily_downloads.each do |daily|
          downloads_saved = project.agility.quarters[daily['date'].to_datetime].delta_downloads.to_i
          project.agility.quarters[daily['date'].to_datetime].delta_downloads = downloads_saved + daily['daily_downloads']
        end

        prev_downloads_delta = 0
        project.agility.quarters.each_sorted do |start_date, stat|
          prev_downloads_delta  = stat.delta_downloads.to_i - prev_downloads_delta
          project.agility.quarters[start_date].download_divergence = divergence(
            prev_downloads_delta, downloads_till_now['total_downloads']
          )
        end
      end

      private

      def divergence(delta, total)
        (delta.to_f / total.to_f * 100.0).round(2)
      end
    end

    class GitHub
      # check on this danryan/jquery-validation-rails
      attr_reader :client, :project
      # delegate community and agility to project

      def initialize(project)
        @client = ::Octokit::Client.new(:access_token => ENV["GHTOKEN"])
        client.default_media_type = 'application/vnd.github.v3.star+json'

        @project = project
        @owner = project.gh_alias.split('/')[0]
      end

      def issues
        @issues ||= client.issues(project.gh_alias, state: :all)# .index_by { |i| i[:url] }
      end

      def issues_comments
        @issues_comments ||= client.issues_comments(project.gh_alias)# .index_by { |i| i[:url] }
        # @issues_comments_by_user = @issues_comments.values.index_by { |i| i[:user][:login] }
      end

      def pulls
        # fetch pull requests, identify by "url", store: "assignee", "milestone", created_at/updated_at, "user"
        # http://octokit.github.io/octokit.rb/Octokit/Client/PullRequests.html#pull_requests_comments-instance_method
        # fetch comments and link with PR by "pull_request_url"
        @pulls ||= client.pull_requests(project.gh_alias, state: :all)# .index_by { |p| p[:url] }
      end

      def pulls_comments
        # fetch pull requests, identify by "url", store: "assignee", "milestone", created_at/updated_at, "user"
        # http://octokit.github.io/octokit.rb/Octokit/Client/PullRequests.html#pull_requests_comments-instance_method
        # fetch comments and link with PR by "pull_request_url"
        @pulls_comments ||= client.pulls_comments(project.gh_alias)# .index_by { |pc| pc[:url] }
        #@pulls_comments_by_user = @pulls_comments.values.index_by { |i| i[:user][:login] }
      end

      def contributors
        @contributors ||= client.contribs(project.gh_alias)# .index_by { |c| c[:login] }
      end

      def stargazers
        @stargazers ||= client.stargazers(project.gh_alias)# .index_by { |s| s[:login] }
      end

      def watchers
        @watchers ||= client.subscribers(project.gh_alias)# .index_by { |w| w[:login] }
      end

      def forkers
        @forkers ||= client.forks(project.gh_alias)# .index_by { |f| f[:owner][:login] }
      end

      def branches
        @branches ||= client.branches(project.gh_alias)# .index_by { |b| b[:name] }
      end

      def tags
        @tags ||= client.tags(project.gh_alias)# .index_by { |b| b[:tag_name] }
      end

      def commits
        @commits ||= client.commits(project.gh_alias)
      end

      def commit(sha)
        client.commit(project.gh_alias, sha)
      end

      def tag_info(sha)
        client.tag(project.gh_alias, sha)
      rescue Octokit::NotFound
        false
      end

      def date_from_tag(sha)
        tag_info = tag_info(sha)
        return tag_info[:tagger][:date] if tag_info
        commit(sha)[:commit][:committer][:date]
      end

      def commits_since(date)
        client.commits_since(project.gh_alias, date)
      end

      def latest_release
        @latest_release ||= client.latest_release(project.gh_alias)
      end

      def process
        # TODO: what to choose? !!!updated_at!!! vs created_at ???
        # we must track latest changes. so updated_at is correct
        project.community.total.contributors.merge(contributors.map { |c| c[:login] })
        project.community.total.users_involved.merge(project.community.total.contributors)
        # @contributors.each do |contrib|
        #   # FUUUUU... no dates included !!!!
        #   # total (+ by quarter)
        #   # total_users_involved (+ by quarter)
        #   # project.community.total_users_involved << contrib[:user][:login]
        #   # project.community.quarters[issue[:updated_at]].total_users_involved << issue[:user][:login]
        # end

        issues.each do |issue|
          # select open, closed, owner, non_owner, total
          # first date, last date
          #
          # open for quarter, closed for quarter
          #
          # users_writing_issues (+ by quarter)
          # total_users_involved (+ by quarter)
          case issue[:state]
          when 'open'
            project.agility.total.issues_open << issue[:url]
            project.agility.quarters[issue[:updated_at]].issues_open << issue[:url]
          when 'closed'
            project.agility.total.issues_closed << issue[:url]
            project.agility.quarters[issue[:updated_at]].issues_closed << issue[:url]
          end

          if issue[:user][:login] == @owner
            project.agility.total.issues_non_owner << issue[:url]
          else
            project.agility.total.issues_owner << issue[:url]
          end

          project.agility.total.issues_total << issue[:url]
          if project.agility.total.first_issue_date.nil? || issue[:updated_at] < project.agility.total.first_issue_date
            project.agility.total.first_issue_date = issue[:updated_at]
          end

          if project.agility.total.last_issue_date.nil? || issue[:updated_at] > project.agility.total.last_issue_date
            project.agility.total.last_issue_date = issue[:updated_at]
          end

          project.community.total.users_creating_issues << issue[:user][:login]
          project.community.quarters[issue[:updated_at]].users_creating_issues << issue[:user][:login]
          project.community.total.users_involved << issue[:user][:login]
          project.community.quarters[issue[:updated_at]].users_involved << issue[:user][:login]
        end

        issues_comments.each do |issue_comment|
          issue_url = /\A(.*)#issuecomment.*\z/.match(issue_comment[:html_url])[1]

          if project.community.total.contributors.include? issue_comment[:user][:login]
            project.agility.total.issues_with_contrib_comments << issue_url
          end

          project.community.total.users_commenting_issues << issue_comment[:user][:login]
          project.community.quarters[issue_comment[:updated_at]].users_commenting_issues << issue_comment[:user][:login]
          project.community.total.users_involved << issue_comment[:user][:login]
          project.community.quarters[issue_comment[:updated_at]].users_involved << issue_comment[:user][:login]
        end

        pulls.each do |pull|
          case pull[:state]
          when 'open'
            project.agility.total.pr_open << pull[:url]
            project.agility.quarters[pull[:updated_at]].pr_open << pull[:url]
          when 'closed'
            project.agility.total.pr_closed << pull[:url]
            project.agility.quarters[pull[:updated_at]].pr_closed << pull[:url]
          end

          if pull[:user][:login] == @owner
            project.agility.total.pr_non_owner << pull[:url]
          else
            project.agility.total.pr_owner << pull[:url]
          end

          project.agility.total.pr_total << pull[:url]

          if project.agility.total.first_pr_date.nil? || pull[:updated_at] < project.agility.total.first_pr_date
            project.agility.total.first_pr_date = pull[:updated_at]
          end

          if project.agility.total.last_pr_date.nil? || pull[:updated_at] > project.agility.total.last_pr_date
            project.agility.total.last_pr_date = pull[:updated_at]
          end

          project.community.total.users_creating_pr << pull[:user][:login]
          project.community.quarters[pull[:updated_at]].users_creating_pr << pull[:user][:login]
          project.community.total.users_involved << pull[:user][:login]
          project.community.quarters[pull[:updated_at]].users_involved << pull[:user][:login]
        end

        pulls_comments.each do |pull_comment|
          if project.community.total.contributors.include? pull_comment[:user][:login]
            project.agility.total.pr_with_contrib_comments << pull_comment[:pull_request_url]
          end

          project.community.total.users_commenting_pr << pull_comment[:user][:login]
          project.community.quarters[pull_comment[:updated_at]].users_commenting_pr << pull_comment[:user][:login]
          project.community.total.users_involved << pull_comment[:user][:login]
          project.community.quarters[pull_comment[:updated_at]].users_involved << pull_comment[:user][:login]
        end

        @latest_release_sha = nil
        tags.each do |tag|
          tag_date = if @latest_release_date.nil?
            @latest_release_date = date_from_tag(tag[:commit][:sha])
          else
            date_from_tag(tag[:commit][:sha])
          end
          project.agility.total.releases_total_gh << tag[:name]
          project.agility.quarters[tag_date].releases_total_gh << tag[:name]
        end

        # latest release = http://octokit.github.io/octokit.rb/Octokit/Client/Releases.html#latest_release-instance_method
        # commits_count_since_last_release = http://octokit.github.io/octokit.rb/Octokit/Client/Commits.html#commits_since-instance_method
        project.agility.total.last_release_date = @latest_release_date# wrong: last_release_commit[:commit][:committer][:date]
        project.agility.total.commits_count_since_last_release = commits_since(@latest_release_date).length

        # ... better to use just `git` ???
        # @commits.each do |commit|
        #   # by quarter
        #   project.agility.commits << commit[:sha]
        #   project.agility.quarters[???].commits << commit[:sha]
        # end

        branches.each do |branch|
          # stale and total
          # by quarter ? date from commit -> [:commit][:committer][:date]
          # 1. save dates by commit sha.
          branch_updated_at = commit(branch[:commit][:sha])[:commit][:committer][:date]
          stale_threshold = Time.now.beginning_of_quarter

          project.agility.total.branches << branch[:name]
          project.agility.total.stale_branches << branch[:name] if branch_updated_at < stale_threshold
          project.agility.quarters[branch_updated_at].branches << branch[:name]
          # 2. date -> total by quarter
          #    date -> stale
        end

        project.community.total.stargazers.merge(stargazers.map { |s| s[:login] })
        project.community.total.users_involved.merge(project.community.total.stargazers)
        stargazers.each do |stargazer|
          project.community.quarters[stargazer[:starred_at]].stargazers << stargazer[:user][:login]
          project.community.quarters[stargazer[:starred_at]].users_involved << stargazer[:user][:login]
        end

        project.community.total.watchers.merge(watchers.map { |w| w[:login] })
        project.community.total.users_involved.merge(project.community.total.watchers)
        # @watchers.each do |contrib|
        #   # total (+ by quarter) NO DATES!!! FUUUU...
        #   # total_users_involved (+ by quarter)
        # end

        project.community.total.forks.merge(forkers.map { |f| f[:owner][:login] })
        project.community.total.users_involved.merge(project.community.total.forks)

        forkers.each do |forker|
          project.community.quarters[forker[:created_at]].forks << forker[:owner][:login]
          project.community.quarters[forker[:created_at]].users_involved << forker[:owner][:login]
        end

        # Agility
        # attr_accessor :issues_open, :issues_closed, :issues_owner, :issues_non_owner, :issues_with_contrib_comments, :issues_total,
        #               :pr_open, :pr_merged, :pr_closed, :pr_owner, :pr_non_owner, :pr_with_contrib_comments, :pr_total,
        #               :first_pr_date, :last_pr_date, :first_issue_date, :last_issue_date,
        #               :releases_total_gh, :releases_total_rg, :last_release_date, :commits_count_since_last_release,
        #               :stale_branches, :total_branches, :total_downloads
        #
        # attr_accessor :issues_open, :issues_closed, :pr_open, :pr_merged, :pr_closed, :releases,
        #               :download_divergence, :branches

        # Community
        # attr_accessor :users_creating_issues, :users_commenting_issues, :users_creating_pr, :users_commenting_pr,
        #               :contributors, :contributors, :watchers, :stargazers, :forks,
        #               :owner_github, :owners_rubygems, :total_users_involved
        #
        # attr_accessor :users_writing_issues, :users_creating_pr, :contributors, # NO DATES. FUUUU... :watchers, :stargazers, :forks,
        #               :total_users_involved
      end

      def load
        if File.exists?("data/gh.#{project.gh_alias}.json")
          Oj.load File.read("data/gh.#{project.gh_alias}.json")
        end

        self
      end

      def dump
        existance_backup("data/gh.#{project.gh_alias}.json")
        File.open("data/gh.#{project.gh_alias}.json","w") do |f|
          f.write(Oj.dump(projects))
        end
      end
    end
  end
end
