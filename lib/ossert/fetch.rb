require 'nokogiri'
require 'open-uri'
require 'benchmark'

module Ossert
  module Fetch
    def all_by_names(names)
      names.each do |name|
        puts "Fetching project '#{name}'..."
        all(Project.new(name, nil, name))
        puts "Done."
        sleep(1)
      end
      nil
    end
    module_function :all_by_names

    def all(project)
      [Rubygems, Bestgems, GitHub].each do |fetcher|
        puts "======> with #{fetcher}..."
        time = Benchmark.realtime {
          fetcher.new(project).process
        }
        puts "<====== Finished in #{time.round(3)} sec."
        sleep(1)
      end
      nil
    end
    module_function :all

    # Example
    #   projects_without_gh_data = Ossert::Project.projects.select { |proj| proj.gh_alias.blank? }
    #   projects_without_gh_data.each { |prj| Ossert::Fetch.only([Ossert::Fetch::Rubygems, Ossert::Fetch::GitHub], prj) }
    def only(fetchers, project, process = :process)
      fetchers = Array.wrap(fetchers)
      puts "Fetching project '#{project.name}'..."
      ([Rubygems, Bestgems, GitHub] & fetchers).each do |fetcher|
        puts "======> with #{fetcher}..."
        time = Benchmark.realtime {
          fetcher.new(project).send(process)
        }
        puts "<====== Finished in #{time.round(3)} sec."
        sleep(1)
      end
      nil
    end
    module_function :only

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

    class BestgemsDailyStat
      def self.process_page(page = nil)
        doc = Nokogiri::HTML(open("http://bestgems.org/daily#{page ? "?page=#{page}" : '' }"))
        doc.css("table").xpath('//tr//td').each_slice(4) do |rank, downloads, name, _|
          rank = rank.text.gsub(',', '').to_i
          downloads = downloads.text.gsub(',', '').to_i
          yield(rank, downloads, name.text)
        end
      end
    end

    class BestgemsTotalStat
      def self.process_page(page = nil)
        doc = Nokogiri::HTML(open("http://bestgems.org/total#{page ? "?page=#{page}" : '' }"))
        doc.css("table").xpath('//tr//td').each_slice(4) do |rank, downloads, name, _|
          rank = rank.text.gsub(',', '').to_i
          downloads = downloads.text.gsub(',', '').to_i
          yield(rank, downloads, name.text)
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

      def info
        @info ||= client.get("gems/#{project.rg_alias}.json")
      end

      def releases
        @releases ||= client.get("versions/#{project.rg_alias}.json")
      end

      def process
        if project.gh_alias.blank?
          match = info['source_code_uri'].try(:match, /github.com\/([a-zA-Z0-9\.\_\-]+)\/([a-zA-Z0-9\.\_\-]+)/)
          match ||= info['homepage_uri'].try(:match, /github.com\/([a-zA-Z0-9\.\_\-]+)\/([a-zA-Z0-9\.\_\-]+)/)
          project.gh_alias = "#{match[1]}/#{match[2]}" if match
        end

        return if project.agility.total.releases_total_rg.present?
        releases.each do |release|
          project.agility.total.releases_total_rg << release['number']
          project.agility.quarters[release['created_at']].releases_total_rg << release['number']
        end
      end
    end

    class Bestgems
      # Community
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
          downloads_saved = project.community.quarters[total['date']].total_downloads.to_i
          project.community.quarters[total['date']].total_downloads = [downloads_saved, total['total_downloads']].max
        end
        project.community.total.total_downloads = downloads_till_now['total_downloads']

        daily_downloads.each do |daily|
          downloads_saved = project.community.quarters[daily['date']].delta_downloads.to_i
          project.community.quarters[daily['date']].delta_downloads = downloads_saved + daily['daily_downloads']
        end

        prev_downloads_delta = 0
        project.community.quarters.each_sorted do |start_date, stat|
          prev_downloads_delta  = stat.delta_downloads.to_i - prev_downloads_delta
          project.community.quarters[start_date].download_divergence = divergence(
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
        client.auto_paginate = true

        @project = project
        raise ArgumentError unless (@repo_name = project.gh_alias).present?
        @owner = @repo_name.split('/')[0]
        @requests_count = 0
      end

      # DO NOT WORK CORRECTLY!!!! FUUUUU....
      # def find_repo(user)
      #   first_found = client.search_repos(project.name, language: :ruby, user: user)[:items].first
      #   first_found.try(:[], :full_name)
      # end

      def request(endpoint, *args)
        # raise 'Requests limit reached' if @requests_count % 500 == 0 && client.rate_limit![:remaining] < 30
        # @requests_count += 1
        # client.send(endpoint, *args, &block)
        first_response_data = client.paginate(url(endpoint, args.shift), *args) do |_, last_response|
          last_response.data.each { |data| yield data }
        end
        first_response_data.each { |data| yield data }
      end

      def url(endpoint, repo_name)
        path = case endpoint
               when /issues_comments/
                 "issues/comments"
               when /pulls_comments/
                 "pulls/comments"
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
        # @stargazers ||= client.stargazers(@repo_name, :accept =>'application/vnd.github.v3.star+json')
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

      def last_year_commits
        last_year_commits = []
        retry_count = 3
        while last_year_commits.blank? && retry_count > 0
          last_year_commits = client.commit_activity_stats(@repo_name)
          if last_year_commits.blank?
            sleep(15*retry_count)
            retry_count -= 1
          end
        end
        last_year_commits
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
        DateTime.new(*value.split('-'.freeze).map(&:to_i)).to_i
      end

      def commits_since(date)
        client.commits_since(@repo_name, date)
      end

      def latest_release
        @latest_release ||= client.latest_release(@repo_name)
      end

      def process_commits
        last_year_commits.each do |week|
          current_count = project.agility.total.last_year_commits.to_i
          project.agility.total.last_year_commits = current_count + week['total']

          current_quarter_count = project.agility.quarters[week['week']].commits.to_i
          project.agility.quarters[week['week']].commits = current_quarter_count + week['total']
        end
      end

      def process_last_release_date
        latest_release_date = 0

        tags do |tag|
          tag_date = date_from_tag(tag[:commit][:sha])
          latest_release_date = [latest_release_date, tag_date].max

          project.agility.total.releases_total_gh << tag[:name]
          project.agility.quarters[tag_date].releases_total_gh << tag[:name]
        end

        unless latest_release_date.zero?
          project.agility.total.last_release_date = latest_release_date# wrong: last_release_commit[:commit][:committer][:date]
          project.agility.total.commits_count_since_last_release = commits_since(Time.at(latest_release_date)).length
        end
      end

      def process_issues_and_prs_processing_days
        issues_processed_in_days = 0
        issues_processed_count = 0
        issues do |issue|
          next if issue.key? :pull_request
          next unless issue[:state] == 'closed'
          next unless issue[:closed_at].present?
          days_to_close = (Date.parse(issue[:closed_at]) - Date.parse(issue[:created_at])).to_i + 1
          issues_processed_in_days += days_to_close
          issues_processed_count += 1
        end

        project.agility.total.issues_processed_in_avg = if issues_processed_count.zero?
                                                          0
                                                        else
                                                          issues_processed_in_days / issues_processed_count
                                                        end

        pulls_processed_in_days = 0
        pulls_processed_count = 0
        pulls do |pull|
          next unless pull[:state] == 'closed'
          next unless pull[:closed_at].present?
          days_to_close = (Date.parse(pull[:closed_at]) - Date.parse(pull[:created_at])).to_i + 1
          pulls_processed_in_days += days_to_close
          pulls_processed_count += 1
        end

        project.agility.total.pr_processed_in_avg = if pulls_processed_count.zero?
                                                      0
                                                    else
                                                      pulls_processed_in_days / pulls_processed_count
                                                    end
      end

      def process_issues_and_prs_processing_time
        # TODO: go for each quarter data
        # => how many quarters does it take in average, to close pr and issue
        issues_processing_periods = Hash.new { |h, k| h[k] = 0 }
        pr_processing_periods = Hash.new { |h, k| h[k] = 0 }

        project.agility.quarters.each_sorted do |quarter, data|
          data.pr_actual.each { |pr| pr_processing_periods[pr] += 1 }
          data.pr_open.each { |pr| pr_processing_periods[pr] += 1 }
          periods = pr_processing_periods.values

          data.issues_actual.each { |issue| issues_processing_periods[issue] += 1 }
          data.issues_open.each { |issue| issues_processing_periods[issue] += 1 }
          periods = issues_processing_periods.values
        end

        periods = pr_processing_periods.values
        project.agility.total.pr_processed_in_avg = periods.empty? ? 0 : periods.sum / periods.count.to_d.to_f

        periods = issues_processing_periods.values
        project.agility.total.issues_processed_in_avg = periods.empty? ? 0 : periods.sum / periods.count.to_d.to_f
      end

      def process_actual_prs_and_issues
        actual_prs, actual_issues = Set.new, Set.new
        project.agility.quarters.each_sorted do |quarter, data|
          data.pr_actual = actual_prs
          data.issues_actual = actual_issues

          closed = data.pr_closed + data.issues_closed
          actual_prs = (actual_prs + data.pr_open) - closed
          actual_issues = (actual_issues + data.issues_open) - closed
        end
      end

      def process_pr_with_contrib_comments_fix
        prev_prs = project.agility.total.pr_with_contrib_comments
        project.agility.total.pr_with_contrib_comments = Set.new(
          prev_prs.map { |pr_link| issue2pull_url(pr_link) }
        )
      end

      def issue2pull_url(html_url)
        html_url.gsub(
          %r{https://github.com/(#{@repo_name})/pull/(\d+)},
          'https://api.github.com/repos/\2/pulls/\3'
        )
      end

      def fix_issues_and_prs_with_contrib_comments
        project.agility.total.pr_with_contrib_comments.delete_if do |pr|
          !(pr =~ %r{https://api.github.com/repos/#{@repo_name}/pulls/\d+})
        end

        project.agility.total.issues_with_contrib_comments.delete_if do |issue|
          !(issue =~ %r{https://github.com/#{@repo_name}/issues/\d+})
        end
      end

      def process_pulls
        pulls_processed_in_days = 0
        pulls_processed_count = 0

        pulls do |pull|
          case pull[:state]
          when 'open'
            project.agility.total.pr_open << pull[:url]
            project.agility.quarters[pull[:created_at]].pr_open << pull[:url]
          when 'closed'
            project.agility.total.pr_closed << pull[:url]
            project.agility.quarters[pull[:created_at]].pr_open << pull[:url]
            project.agility.quarters[pull[:closed_at]].pr_closed << pull[:url] if pull[:closed_at]
            project.agility.quarters[pull[:merged_at]].pr_merged << pull[:url] if pull[:merged_at]
            if pull[:closed_at].present?
              days_to_close = (Date.parse(pull[:closed_at]) - Date.parse(pull[:created_at])).to_i + 1
              pulls_processed_in_days += days_to_close
              pulls_processed_count += 1
            end
          end

          if pull[:user][:login] == @owner
            project.agility.total.pr_owner << pull[:url]
          else
            project.agility.total.pr_non_owner << pull[:url]
          end

          project.agility.total.pr_total << pull[:url]
          project.agility.quarters[pull[:created_at]].pr_total << pull[:url]

          if project.agility.total.first_pr_date.nil? || pull[:created_at] < project.agility.total.first_pr_date
            project.agility.total.first_pr_date = pull[:created_at]
          end

          if project.agility.total.last_pr_date.nil? || pull[:created_at] > project.agility.total.last_pr_date
            project.agility.total.last_pr_date = pull[:created_at]
          end

          project.community.total.users_creating_pr << pull[:user][:login]
          project.community.quarters[pull[:created_at]].users_creating_pr << pull[:user][:login]
          project.community.total.users_involved << pull[:user][:login]
          project.community.quarters[pull[:created_at]].users_involved << pull[:user][:login]
        end

        project.agility.total.pr_processed_in_avg = if pulls_processed_count.zero?
                                                      0
                                                    else
                                                      pulls_processed_in_days / pulls_processed_count
                                                    end

        pulls_comments do |pull_comment|
          login = pull_comment[:user].try(:[], :login).presence || generate_anonymous
          if project.community.total.contributors.include? login
            project.agility.total.pr_with_contrib_comments << pull_comment[:pull_request_url]
          end

          project.community.total.users_commenting_pr << login
          project.community.quarters[pull_comment[:created_at]].users_commenting_pr << login
          project.community.total.users_involved << login
          project.community.quarters[pull_comment[:created_at]].users_involved << login
        end

      end

      def process_issues
        issues_processed_in_days = 0
        issues_processed_count = 0
        issues do |issue|
          next if issue.key? :pull_request
          case issue[:state]
          when 'open'
            project.agility.total.issues_open << issue[:url]
            project.agility.quarters[issue[:created_at]].issues_open << issue[:url]
          when 'closed'
            project.agility.total.issues_closed << issue[:url]
            # if issue is closed for now, it also was opened somewhen
            project.agility.quarters[issue[:created_at]].issues_open << issue[:url]
            project.agility.quarters[issue[:closed_at]].issues_closed << issue[:url] if issue[:closed_at]

            if issue[:closed_at].present?
              days_to_close = (Date.parse(issue[:closed_at]) - Date.parse(issue[:created_at])).to_i + 1
              issues_processed_in_days += days_to_close
              issues_processed_count += 1
            end
          end

          if issue[:user][:login] == @owner
            project.agility.total.issues_owner << issue[:url]
          else
            project.agility.total.issues_non_owner << issue[:url]
          end

          project.agility.total.issues_total << issue[:url]
          project.agility.quarters[issue[:created_at]].issues_total << issue[:url]
          if project.agility.total.first_issue_date.nil? || issue[:created_at] < project.agility.total.first_issue_date
            project.agility.total.first_issue_date = issue[:created_at]
          end

          if project.agility.total.last_issue_date.nil? || issue[:created_at] > project.agility.total.last_issue_date
            project.agility.total.last_issue_date = issue[:created_at]
          end

          project.community.total.users_creating_issues << issue[:user][:login]
          project.community.quarters[issue[:created_at]].users_creating_issues << issue[:user][:login]
          project.community.total.users_involved << issue[:user][:login]
          project.community.quarters[issue[:created_at]].users_involved << issue[:user][:login]
        end

        project.agility.total.issues_processed_in_avg = if issues_processed_count.zero?
                                                          0
                                                        else
                                                          issues_processed_in_days / issues_processed_count
                                                        end

        issues_comments do |issue_comment|
          login = issue_comment[:user].try(:[], :login).presence || generate_anonymous
          issue_url = /\A(.*)#issuecomment.*\z/.match(issue_comment[:html_url])[1]
          if issue_url.include?('/pull/') # PR comments are stored as Issue comments. Sadness =(
            if project.community.total.contributors.include? login
              project.agility.total.pr_with_contrib_comments << issue2pull_url(issue_url)
            end

            project.community.total.users_commenting_pr << login
            project.community.quarters[issue_comment[:created_at]].users_commenting_pr << login
            project.community.total.users_involved << login
            project.community.quarters[issue_comment[:created_at]].users_involved << login
            next
          end

          if project.community.total.contributors.include? login
            project.agility.total.issues_with_contrib_comments << issue_url
          end

          project.community.total.users_commenting_issues << login
          project.community.quarters[issue_comment[:created_at]].users_commenting_issues << login
          project.community.total.users_involved << login
          project.community.quarters[issue_comment[:created_at]].users_involved << login
        end
      end

      def process
        # TODO: what to choose? !!!updated_at!!! vs created_at ???
        # we must track latest changes. so updated_at is correct
        contributors do |c|
          login = c.try(:[], :login).presence || generate_anonymous
          project.community.total.contributors << login
        end#
        project.community.total.users_involved.merge(project.community.total.contributors)

        process_issues

        process_pulls

        process_actual_prs_and_issues

        process_last_release_date

        process_commits

        branches do |branch|
          # stale and total
          # by quarter ? date from commit -> [:commit][:committer][:date]
          # 1. save dates by commit sha.
          branch_updated_at = commit(branch[:commit][:sha])[:commit][:committer][:date]
          stale_threshold = Time.now.beginning_of_quarter

          # 2. date -> total by quarter
          #    date -> stale
          project.agility.total.branches << branch[:name]
          project.agility.total.stale_branches << branch[:name] if branch_updated_at < stale_threshold
          project.agility.quarters[branch_updated_at].branches << branch[:name]
        end

        stargazers do |stargazer|
          login = stargazer[:user][:login].presence || generate_anonymous
          project.community.total.stargazers << login
          project.community.total.users_involved << login

          project.community.quarters[stargazer[:starred_at]].stargazers << login
          project.community.quarters[stargazer[:starred_at]].users_involved << login
        end

        watchers do |watcher|
          login = watcher[:login].presence || generate_anonymous
          project.community.total.watchers << login
          project.community.total.users_involved << login
        end

        forkers do |forker|
          project.community.total.forks << forker[:owner][:login]
          project.community.total.users_involved << forker[:owner][:login]
          project.community.quarters[forker[:created_at]].forks << forker[:owner][:login]
          project.community.quarters[forker[:created_at]].users_involved << forker[:owner][:login]
        end
      rescue Octokit::NotFound => e
        raise "Github NotFound Error: #{e.inspect}"
      end

      def generate_anonymous
        @anonymous_count ||= 0
        @anonymous_count += 1
        "anonymous_#{@anonymous_count}"
      end
    end
  end
end
