module Ossert
  module Fetch
    class Reddit
      attr_reader :client, :project

      extend Forwardable
      def_delegators :project, :agility, :community, :meta

      BASE_URL = "https://www.reddit.com"
      SUBREDDIT_NEW_PATH = "/r/%s/new.json"
      SUBREDDIT_TOP_PATH = "/r/%s/top.json?sort=top&t=all"

      MAX_PAGES_COUNT = 10

      class Metrics
        attr_reader :mentions, :users

        def initialize
          @mentions = {}
          @users = Set.new
        end

        def add_mention(created_utc)
          mentions[created_utc.to_i] ||= 0
          mentions[created_utc.to_i] += 1
        end

        def total_mentions
          mentions.values.inject(:+)
        end
        
        # Unique users who comments posts
        def add_commenter_user(author)
          users << author unless author.nil?
        end
      end

      def initialize(project)
        @client = SimpleClient.new(BASE_URL)
        @project = project
        @metrics = Metrics.new
      end

      def process_subreddit(subreddit_name, sort = :new)
        response, after = nil, nil
        MAX_PAGES_COUNT.times { |i|
          response = sort == :new ? fetch_new(subreddit_name, after) : fetch_top(subreddit_name, after)
          next if response['data']['children'].empty?

          after = response['data']['children'].last['data']['name']
          response['data']['children'].each do |post|
            process_post(post['data'])
          end
        }
      end
      
      def process
        return if project.reddit_name.nil?
        project.reddit_name.split(",").each {|name| process_subreddit(name.strip, :new)}
        project.reddit_name.split(",").each {|name| process_subreddit(name.strip, :top)}

        community.total.last_mentions = @metrics.total_mentions
        @metrics.mentions.each do |date, stat|
          community.quarters[date].last_mentions = stat
        end

        community.total.users_commenting_posts.merge(@metrics.users)
      end

      protected
        def subreddit_path(subreddit_name, path_pattern, after = nil, limit = 100)
          params = { limit: limit }
          params[:after] = after unless after.nil?
          query = params.map{ |k, v| "#{k}=#{v}" }.join("&")
          "#{path_pattern % subreddit_name}#{path_pattern.include?("?") ? "&" : "?"}#{query}"
        end

        def fetch_new(subreddit_name, after = nil)
          @client.get(subreddit_path(subreddit_name, SUBREDDIT_NEW_PATH, after))
        end

        def fetch_top(subreddit_name, after = nil)
          @client.get(subreddit_path(subreddit_name, SUBREDDIT_TOP_PATH, after))
        end

        def process_reply(reply)
          if reply['data'].present? and reply['data']['children'].present?
            reply['data']['children'].each do |child|
              
              if child['data']['body'] =~ /#{Regexp.escape(@project.name)}/i
                @metrics.add_mention(child['data']['created_utc'])
              end

              @metrics.add_commenter_user(child['data']['author'])

              unless child['data']['replies'].nil?
                process_reply(child['data']['replies'])
              end
            end
          end
        end

        def process_post(data)
          if data['selftext'] =~ /#{Regexp.escape(@project.name)}/i || 
              data['title'] =~ /#{Regexp.escape(@project.name)}/i
            
            @metrics.add_mention(data['created_utc'])
            @metrics.add_commenter_user(data['author'])

            if data['num_comments'].to_i > 0
              response = @client.get("#{data['permalink']}.json")
              response.each do |reply|
                process_reply(reply)
              end
            end
          end
        end
    end
  end
end

# https://www.reddit.com/r/rails/search.json?q=rake&sort=new&restrict_sr=true&limit=1