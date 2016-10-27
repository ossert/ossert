# https://api.stackexchange.com/2.2/search?order=desc&sort=activity&intitle=multi_json&site=stackoverflow&key=KM0jqjZaKZZYULSYGXEuhw((
module Ossert
  module Fetch
    class Stackoverflow
      attr_reader :client, :project

      extend Forwardable
      def_delegators :project, :agility, :community, :meta

      BASE_URL = "https://api.stackexchange.com"
      SEARCH_PATH = "/2.2/search?pagesize=100&order=asc&sort=creation&intitle=%s&site=stackoverflow&key=#{ENV['STACKOVERFLOW_KEY']}&fromdate=%d&todate=%d&page=%d"
      ANSWERS_PATH = "/2.2/questions/%s/answers?order=asc&sort=creation&site=stackoverflow&key=#{ENV['STACKOVERFLOW_KEY']}&page=%d"
      
      class Metrics
        attr_accessor :questions_count,
                      :answers_count, 
                      :answers_count_avg, 
                      :views_count, 
                      :question_owner_reputation_avg, 
                      :users_who_answered,
                      :answered_questions

        def initialize
          @questions_count = 0
          @answers_count = 0
          @answers_count_avg = 0
          @views_count = 0
          @question_owner_reputation_avg = 0
          @users_who_answered = Set.new
          @answered_questions = 0
        end

        def answered_questions_divergence
          v = divergence(@answered_questions, @questions_count)
          v.nan? ? 0 : v
        end
        
        private
          # FIXME copy-paste from betsgems
          def divergence(delta, total)
            (delta.to_f / total.to_f * 100.0).round(2)
          end
      end

      def initialize(project)
        @client = SimpleClient.new(BASE_URL)
        @project = project
        @fixed_time_now = Time.now
      end

      def process
        last_release = Metrics.new
        last_month = Metrics.new

        process_for(:last_month, last_month)
        process_for(:last_release, last_release)
        
        community.total.last_month_questions = last_month.questions_count
        community.total.last_month_answers = last_month.answers_count
        community.total.last_month_answers_avg = last_month.answers_count_avg
        community.total.last_month_questions_views = last_month.views_count
        community.total.last_month_question_owner_reputation_avg = last_month.question_owner_reputation_avg
        community.total.last_month_users_who_answered.merge(last_month.users_who_answered)
        community.total.last_month_answered_questions = last_month.answered_questions
        community.total.last_month_answered_questions_divergence = last_month.answered_questions_divergence

        rd = agility.total.last_release_date
        community.quarters[rd].questions = last_release.questions_count
        community.quarters[rd].answers = last_release.answers_count
        community.quarters[rd].answers_avg = last_release.answers_count_avg
        community.quarters[rd].questions_views = last_release.views_count
        community.quarters[rd].question_owner_reputation_avg = last_release.question_owner_reputation_avg
        community.quarters[rd].users_who_answered.merge(last_release.users_who_answered)
        community.quarters[rd].answered_questions = last_release.answered_questions
        community.quarters[rd].answered_questions_divergence = last_release.answered_questions_divergence
        
      end

      class QuotaMax < StandardError; end

      protected
        def process_for(type, metrics, page = 1)
          if type == :last_month
            res = fetch_search(@project.name, (@fixed_time_now - 1.month).to_i, @fixed_time_now.to_i, page)
          elsif type == :last_release
            return if agility.total.last_release_date.nil?
            res = fetch_search(@project.name, agility.total.last_release_date, @fixed_time_now.to_i, page)
          end
          
          raise QuotaMax if res['quota_remaining'] == 0

          if res['items'].count > 0
            metrics.questions_count += res['items'].count
            metrics.answers_count_avg += (res['items'].map { |x| x['answer_count']}.inject(:+).to_f / res['items'].count.to_f).round(2)
            
            reputation_sum = res['items'].map { |x| x['owner']['reputation'].nil? ? 0 : x['owner']['reputation'] }.inject(:+).to_f
            metrics.question_owner_reputation_avg += (reputation_sum / res['items'].count.to_f).round(2)
          end

          question_ids = []
          res['items'].each do |question|
            if question['answer_count'] > 0
              metrics.answers_count += question['answer_count']
              metrics.views_count += question['view_count']
              metrics.answered_questions += 1 if question['is_answered']
              question_ids << question['question_id']
            end
          end

          process_answers(question_ids, metrics)

          if res['has_more']
            process_for(type, metrics, page + 1)
          else
            metrics.answers_count_avg = (metrics.answers_count_avg / page).round(2);
            metrics.question_owner_reputation_avg = (metrics.question_owner_reputation_avg / page).round(2);
          end
        end

        def process_answers(question_ids, metrics, page = 1)
          return if question_ids.nil? or question_ids.empty?
          res = fetch_answers(question_ids, page)
          raise QuotaMax if res['quota_remaining'] == 0

          metrics.users_who_answered.merge(res['items'].map { |x| x['owner']['display_name']})
          
          if res['has_more']
            process_answers(question_ids, metrics, page + 1)
          end
        end

        def fetch_search(text, fromdate, todate, page = 1)
          @client.get(SEARCH_PATH % [text, fromdate, todate, page])
        end

        def fetch_answers(question_ids, page = 1)
          @client.get(ANSWERS_PATH % [question_ids.join(";"), page])
        end
    end
  end
end