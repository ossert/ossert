# frozen_string_literal: true
require 'octokit'

module Ossert
  module Fetch
    class GitHub
      attr_reader :client, :project

      extend Forwardable
      def_delegators :project, :agility, :community, :meta

      def initialize(project)
        @client = ::Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
        client.default_media_type = 'application/vnd.github.v3.star+json'
        client.auto_paginate = true

        @project = project
        raise ArgumentError unless (@repo_name = project.github_alias).present?
        @owner = @repo_name.split('/')[0]
        @requests_count = 0
      end

      # TODO:  Add github search feature
      # def find_repo(user)
      #   first_found = client.search_repos(project.name, language: :ruby, user: user)[:items].first
      #   first_found.try(:[], :full_name)
      # end

      def request(endpoint, *args)
        first_response_data = client.paginate(url(endpoint, args.shift), *args) do |_, last_response|
          last_response.data.each { |data| yield data }
        end
        first_response_data.each { |data| yield data }
      end

      def url(endpoint, repo_name)
        path = case endpoint
               when /issues_comments/
                 'issues/comments'
               when /pulls_comments/
                 'pulls/comments'
               else
                 endpoint
               end
        "#{Octokit::Repository.path repo_name}/#{path}"
      end

      def issues(&block)
        request(:issues, @repo_name, state: :all, &block)
      end

      def issues_comments(&block)
        request(:issues_comments, @repo_name, &block)
      end

      def pulls(&block)
        # fetch pull requests, identify by "url", store: "assignee", "milestone", created_at/updated_at, "user"
        # http://octokit.github.io/octokit.rb/Octokit/Client/PullRequests.html#pull_requests_comments-instance_method
        # fetch comments and link with PR by "pull_request_url"
        request(:pulls, @repo_name, state: :all, &block)
      end

      def pulls_comments(&block)
        # fetch pull requests, identify by "url", store: "assignee", "milestone", created_at/updated_at, "user"
        # http://octokit.github.io/octokit.rb/Octokit/Client/PullRequests.html#pull_requests_comments-instance_method
        # fetch comments and link with PR by "pull_request_url"
        request(:pulls_comments, @repo_name, &block)
      end

      def contributors(&block)
        request(:contributors, @repo_name, anon: true, &block)
      end

      def stargazers(&block)
        request(:stargazers, @repo_name, &block)
      end

      def watchers(&block)
        request(:subscribers, @repo_name, &block)
      end

      def forkers(&block)
        request(:forks, @repo_name, &block)
      end

      def branches(&block)
        request(:branches, @repo_name, &block)
      end

      def tags(&block)
        request(:tags, @repo_name, &block)
      end

      def commits(from, to, &block)
        request(:commits, @repo_name, since: from, until: to, &block)
      end

      def last_year_commits
        last_year_commits = []
        retry_count = 3
        while last_year_commits.blank? && retry_count.positive?
          last_year_commits = client.commit_activity_stats(@repo_name)
          if last_year_commits.blank?
            sleep(15 * retry_count)
            retry_count -= 1
          end
        end
        last_year_commits
      end

      def top_contributors
        client.contributors_stats(@repo_name, retry_timeout: 5, retry_wait: 1)
      end

      def commit(sha)
        client.commit(@repo_name, sha)
      end

      def tag_info(sha)
        client.tag(@repo_name, sha)
      rescue Octokit::NotFound
        false
      end

      def date_from_tag(sha)
        tag_info = tag_info(sha)
        return tag_info[:tagger][:date] if tag_info
        value = commit(sha)[:commit][:committer][:date]
        DateTime.new(*value.split('-').map(&:to_i)).to_i
      end

      def commits_since(date)
        client.commits_since(@repo_name, date)
      end

      def latest_release
        @latest_release ||= client.latest_release(@repo_name)
      end

      # Add class with processing types, e.g. top_contributors, commits and so on

      def process_top_contributors
        @top_contributors = top_contributors.map { |contrib_data| contrib_data[:author][:login] }
        @top_contributors.last(10).reverse.each do |login|
          (meta[:top_10_contributors] ||= []) << "https://github.com/#{login}"
        end
        nil
      end

      def process_commits
        last_year_commits.each do |week|
          current_count = agility.total.last_year_commits.to_i
          agility.total.last_year_commits = current_count + week['total']

          current_quarter_count = agility.quarters[week['week']].commits.to_i
          agility.quarters[week['week']].commits = current_quarter_count + week['total']
        end
      end

      def process_last_release_date
        latest_release_date = 0

        tags do |tag|
          tag_date = date_from_tag(tag[:commit][:sha])
          latest_release_date = [latest_release_date, tag_date].max

          agility.total.releases_total_gh << tag[:name]
          agility.quarters[tag_date].releases_total_gh << tag[:name]
        end

        return if latest_release_date.zero?

        agility.total.last_release_date = latest_release_date # wrong: last_release_commit[:commit][:committer][:date]
        agility.total.commits_count_since_last_release = commits_since(Time.at(latest_release_date).utc).length
      end

      def process_quarters_issues_and_prs_processing_days
        issues do |issue|
          next if issue.key? :pull_request
          next unless issue[:state] == 'closed'
          next unless issue[:closed_at].present?
          days_to_close = (Date.parse(issue[:closed_at]) - Date.parse(issue[:created_at])).to_i + 1
          (agility.quarters[issue[:closed_at]].issues_processed_in_days ||= []) << days_to_close
        end

        pulls do |pull|
          next unless pull[:state] == 'closed'
          next unless pull[:closed_at].present?
          days_to_close = (Date.parse(pull[:closed_at]) - Date.parse(pull[:created_at])).to_i + 1
          (agility.quarters[pull[:closed_at]].pr_processed_in_days ||= []) << days_to_close
        end
      end

      def process_issues_and_prs_processing_days
        @issues_processed_in_days = []
        issues do |issue|
          next if issue.key? :pull_request
          next unless issue[:state] == 'closed'
          next unless issue[:closed_at].present?
          days_to_close = (Date.parse(issue[:closed_at]) - Date.parse(issue[:created_at])).to_i + 1
          @issues_processed_in_days << days_to_close
          (agility.quarters[issue[:closed_at]].issues_processed_in_days ||= []) << days_to_close
        end

        values = @issues_processed_in_days.to_a.sort
        agility.total.issues_processed_in_avg = if values.count.odd?
                                                  values[values.count / 2]
                                                elsif values.count.zero?
                                                  0
                                                else
                                                  ((values[values.count / 2 - 1] + values[values.count / 2]) / 2.0).to_i
                                                end

        @pulls_processed_in_days = []
        pulls do |pull|
          next unless pull[:state] == 'closed'
          next unless pull[:closed_at].present?
          days_to_close = (Date.parse(pull[:closed_at]) - Date.parse(pull[:created_at])).to_i + 1
          @pulls_processed_in_days << days_to_close
          (agility.quarters[pull[:closed_at]].pr_processed_in_days ||= []) << days_to_close
        end

        values = @pulls_processed_in_days.to_a.sort
        agility.total.pr_processed_in_avg = if values.count.odd?
                                              values[values.count / 2]
                                            elsif values.count.zero?
                                              0
                                            else
                                              ((values[values.count / 2 - 1] + values[values.count / 2]) / 2.0).to_i
                                            end
      end

      def process_actual_prs_and_issues
        actual_prs = Set.new
        actual_issues = Set.new
        agility.quarters.each_sorted do |_quarter, data|
          data.pr_actual = actual_prs.to_a
          data.issues_actual = actual_issues.to_a

          closed = Set.new(data.pr_closed + data.issues_closed)
          actual_prs = Set.new(actual_prs + data.pr_open) - closed
          actual_issues = Set.new(actual_issues + data.issues_open) - closed
        end
      end

      def issue2pull_url(html_url)
        html_url.gsub(
          %r{https://github.com/(#{@repo_name})/pull/(\d+)},
          'https://api.github.com/repos/\2/pulls/\3'
        )
      end

      def process_open_pull(pull)
        agility.total.pr_open << pull[:url]
        agility.quarters[pull[:created_at]].pr_open << pull[:url]
      end

      def process_closed_pull(pull)
        agility.total.pr_closed << pull[:url]
        agility.quarters[pull[:created_at]].pr_open << pull[:url]
        agility.quarters[pull[:closed_at]].pr_closed << pull[:url] if pull[:closed_at]
        agility.quarters[pull[:merged_at]].pr_merged << pull[:url] if pull[:merged_at]

        return unless pull[:closed_at].present?
        days_to_close = (Date.parse(pull[:closed_at]) - Date.parse(pull[:created_at])).to_i + 1
        @pulls_processed_in_days << days_to_close
        (agility.quarters[pull[:closed_at]].pr_processed_in_days ||= []) << days_to_close
      end

      def process_users_from_pull(pull)
        community.total.users_creating_pr << pull[:user][:login]
        community.quarters[pull[:created_at]].users_creating_pr << pull[:user][:login]
        community.total.users_involved << pull[:user][:login]
        community.quarters[pull[:created_at]].users_involved << pull[:user][:login]
      end

      def process_pulls
        @pulls_processed_in_days = Set.new

        retry_call do
          pulls do |pull|
            case pull[:state]
            when 'open'
              process_open_pull(pull)
            when 'closed'
              process_closed_pull(pull)
            end

            if pull[:user][:login] == @owner
              agility.total.pr_owner << pull[:url]
            else
              agility.total.pr_non_owner << pull[:url]
            end

            agility.total.pr_total << pull[:url]
            agility.quarters[pull[:created_at]].pr_total << pull[:url]

            if agility.total.first_pr_date.nil? || pull[:created_at] < agility.total.first_pr_date
              agility.total.first_pr_date = pull[:created_at]
            end

            if agility.total.last_pr_date.nil? || pull[:created_at] > agility.total.last_pr_date
              agility.total.last_pr_date = pull[:created_at]
            end

            process_users_from_pull(pull)
          end
        end

        values = @pulls_processed_in_days.to_a.sort
        agility.total.pr_processed_in_avg = if values.count.odd?
                                              values[values.count / 2]
                                            elsif values.count.zero?
                                              0
                                            else
                                              ((values[values.count / 2 - 1] + values[values.count / 2]) / 2.0).to_i
                                            end


        retry_call do
          pulls_comments do |pull_comment|
            login = pull_comment[:user].try(:[], :login).presence || generate_anonymous
            if community.total.contributors.include? login
              agility.total.pr_with_contrib_comments << pull_comment[:pull_request_url]
            end

            community.total.users_commenting_pr << login
            community.quarters[pull_comment[:created_at]].users_commenting_pr << login
            community.total.users_involved << login
            community.quarters[pull_comment[:created_at]].users_involved << login
          end
        end
      end

      def process_open_issue(issue)
        agility.total.issues_open << issue[:url]
        agility.quarters[issue[:created_at]].issues_open << issue[:url]
      end

      def process_closed_issue(issue)
        agility.total.issues_closed << issue[:url]
        # if issue is closed for now, it also was opened somewhen
        agility.quarters[issue[:created_at]].issues_open << issue[:url]
        agility.quarters[issue[:closed_at]].issues_closed << issue[:url] if issue[:closed_at]

        return unless issue[:closed_at].present?
        days_to_close = (Date.parse(issue[:closed_at]) - Date.parse(issue[:created_at])).to_i + 1
        @issues_processed_in_days << days_to_close
        (agility.quarters[issue[:closed_at]].issues_processed_in_days ||= []) << days_to_close
      end

      def process_users_from_issue(issue)
        community.total.users_creating_issues << issue[:user][:login]
        community.quarters[issue[:created_at]].users_creating_issues << issue[:user][:login]
        community.total.users_involved << issue[:user][:login]
        community.quarters[issue[:created_at]].users_involved << issue[:user][:login]
      end

      def process_issues
        @issues_processed_in_days = []

        issues do |issue|
          next if issue.key? :pull_request
          case issue[:state]
          when 'open'
            process_open_issue(issue)
          when 'closed'
            process_closed_issue(issue)
          end

          if issue[:user][:login] == @owner
            agility.total.issues_owner << issue[:url]
          else
            agility.total.issues_non_owner << issue[:url]
          end

          agility.total.issues_total << issue[:url]
          agility.quarters[issue[:created_at]].issues_total << issue[:url]
          if agility.total.first_issue_date.nil? || issue[:created_at] < agility.total.first_issue_date
            agility.total.first_issue_date = issue[:created_at]
          end

          if agility.total.last_issue_date.nil? || issue[:created_at] > agility.total.last_issue_date
            agility.total.last_issue_date = issue[:created_at]
          end

          process_users_from_issue(issue)
        end

        values = @issues_processed_in_days.to_a.sort
        agility.total.issues_processed_in_avg = if values.count.odd?
                                                  values[values.count / 2]
                                                elsif values.count.zero?
                                                  0
                                                else
                                                  ((values[values.count / 2 - 1] + values[values.count / 2]) / 2.0).to_i
                                                end

        issues_comments do |issue_comment|
          login = issue_comment[:user].try(:[], :login).presence || generate_anonymous
          issue_url = /\A(.*)#issuecomment.*\z/.match(issue_comment[:html_url])[1]
          if issue_url.include?('/pull/') # PR comments are stored as Issue comments. Sadness =(
            if community.total.contributors.include? login
              agility.total.pr_with_contrib_comments << issue2pull_url(issue_url)
            end

            community.total.users_commenting_pr << login
            community.quarters[issue_comment[:created_at]].users_commenting_pr << login
            community.total.users_involved << login
            community.quarters[issue_comment[:created_at]].users_involved << login
            next
          end

          if community.total.contributors.include? login
            agility.total.issues_with_contrib_comments << issue_url
          end

          community.total.users_commenting_issues << login
          community.quarters[issue_comment[:created_at]].users_commenting_issues << login
          community.total.users_involved << login
          community.quarters[issue_comment[:created_at]].users_involved << login
        end
      end

      def process
        contributors do |c|
          login = c.try(:[], :login).presence || generate_anonymous
          community.total.contributors << login
        end
        community.total.users_involved += community.total.contributors
        community.total.users_involved.uniq!

        # TODO: extract contributors and commits, quarter by quarter.
        #
        # => {:sha=>"d1a43d32e615b4a75117151b002266c560ce9061",
        # :commit=>
        #   {:author=>
        #     {:name=>"Yves Senn",
        #     :email=>"yves.senn@gmail.com",
        #     :date=>"2015-09-22T08:25:14Z"},
        #   :committer=>
        #     {:name=>"Yves Senn",
        #     :email=>"yves.senn@gmail.com",
        #     :date=>"2015-09-22T08:25:14Z"},
        #   :message=>
        #     "Merge pull request #21678 from ronakjangir47/array_to_formatted_s_docs\n\nAdded Examples in docs for int
        #     ernal behavior of Array#to_formatted_s [ci skip]",
        #   :tree=>
        #     {:sha=>"204811aa155645b461467dbd2238ac41c0fe8a30",
        #     :url=>
        #       "https://api.github.com/repos/rails/rails/git/trees/204811aa155645b461467dbd2238ac41c0fe8a30"},
        #   :url=>
        #     "https://api.github.com/repos/rails/rails/git/commits/d1a43d32e615b4a75117151b002266c560ce9061",
        #   :comment_count=>0},
        # :url=>
        #   "https://api.github.com/repos/rails/rails/commits/d1a43d32e615b4a75117151b002266c560ce9061",
        # :html_url=>
        #   "https://github.com/rails/rails/commit/d1a43d32e615b4a75117151b002266c560ce9061",
        # :comments_url=>
        #   "https://api.github.com/repos/rails/rails/commits/d1a43d32e615b4a75117151b002266c560ce9061/comments",
        # :author=>
        #   {:login=>"senny",
        #    ...
        #    :type=>"User",
        #    :site_admin=>false},
        # :committer=>
        #   {:login=>"senny",
        #    ...
        #   :type=>"User",
        #   :site_admin=>false},
        # :parents=>
        #   [{:sha=>"2a7e8f54c66dbd65822f2a7135546a240426b631",
        #     :url=>
        #     "https://api.github.com/repos/rails/rails/commits/2a7e8f54c66dbd65822f2a7135546a240426b631",
        #     :html_url=>
        #     "https://github.com/rails/rails/commit/2a7e8f54c66dbd65822f2a7135546a240426b631"},
        #   {:sha=>"192d29f1c7ea16c506c09da2b854d1acdfbc8749",
        #     :url=>
        #     "https://api.github.com/repos/rails/rails/commits/192d29f1c7ea16c506c09da2b854d1acdfbc8749",
        #     :html_url=>
        #     "https://github.com/rails/rails/commit/192d29f1c7ea16c506c09da2b854d1acdfbc8749"}]}

        # process collaborators and commits. year by year, more info then ^^^^^
        # count = 0; collab = Set.new; fetcher.commits(14.months.ago.utc.iso8601, 13.month.ago.utc.iso8601) do |commit|
        #   count+=1
        #   collab << (commit[:author].try(:[],:login) || commit[:commit][:author][:name])
        # end

        process_issues

        process_pulls

        process_actual_prs_and_issues

        process_last_release_date

        process_commits

        sleep(1)

        process_top_contributors

        sleep(1)

        branches do |branch|
          # stale and total
          # by quarter ? date from commit -> [:commit][:committer][:date]
          # 1. save dates by commit sha.
          branch_updated_at = commit(branch[:commit][:sha])[:commit][:committer][:date]
          stale_threshold = Time.now.beginning_of_quarter

          # 2. date -> total by quarter
          #    date -> stale
          agility.total.branches << branch[:name]
          agility.total.stale_branches << branch[:name] if branch_updated_at < stale_threshold
          agility.quarters[branch_updated_at].branches << branch[:name]
        end

        stargazers do |stargazer|
          login = stargazer[:user][:login].presence || generate_anonymous
          community.total.stargazers << login
          community.total.users_involved << login

          community.quarters[stargazer[:starred_at]].stargazers << login
          community.quarters[stargazer[:starred_at]].users_involved << login
        end

        watchers do |watcher|
          login = watcher[:login].presence || generate_anonymous
          community.total.watchers << login
          community.total.users_involved << login
        end

        forkers do |forker|
          community.total.forks << forker[:owner][:login]
          community.total.users_involved << forker[:owner][:login]
          community.quarters[forker[:created_at]].forks << forker[:owner][:login]
          community.quarters[forker[:created_at]].users_involved << forker[:owner][:login]
        end
      rescue Octokit::NotFound => e
        raise "Github NotFound Error: #{e.inspect}"
      end

      MAX_ATTEMPTS = 5

      def retry_call
        attempt = 0
        begin
          yield
        rescue Octokit::InternalServerError => e
          attempt += 1
          raise if attempt > MAX_ATTEMPTS
          puts "Github Error: #{e.inspect}... retrying"
          sleep(attempt * 1.minute)
          retry
        end
      end

      # GitHub sometimes hides login, this is fallback
      def generate_anonymous
        @anonymous_count ||= 0
        @anonymous_count += 1
        "anonymous_#{@anonymous_count}"
      end
    end
  end
end
