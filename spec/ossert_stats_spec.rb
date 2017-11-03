# frozen_string_literal: true
require 'spec_helper'
require 'pry'

describe Ossert do
  describe 'metrics data' do
    let(:projectA) { Ossert::Project.load_by_name(@a_project) }
    let(:projectB) { Ossert::Project.load_by_name(@b_project) }
    let(:projectC) { Ossert::Project.load_by_name(@c_project) }
    let(:projectD) { Ossert::Project.load_by_name(@d_project) }
    let(:projectE) { Ossert::Project.load_by_name(@e_project) }

    it do
      expect(projectA.community.quarters.last_year_as_hash).to eq({
        "answers_avg" => 0.67,
        "authors_count" => 5.0,
        "comments_avg" => 7.0,
        "forks_count" => 6.0,
        "post_score_sum" => 18.0,
        "posts_count" => 5.0,
        "question_score_sum" => 3.0,
        "question_view_sum" => 1118.0,
        "questioner_rep_median" => 16.0,
        "questioners_count" => 6.0,
        "questions_count" => 6.0,
        "questions_resolved_percent" => 33.33,
        "stargazers_count" => 51.0,
        "total_downloads_count" => 57198147.0,
        "users_commenting_issues_count" => 4.0,
        "users_commenting_pr_count" => 4.0,
        "users_creating_issues_count" => 4.0,
        "users_creating_pr_count" => 3.0,
        "users_involved_count" => 66.0,
        "users_involved_no_stars_count" => 15.0,
      })
    end

    it do
      expect(projectA.community.total.metrics_to_hash).to eq({
        "authors_count" => 8,
        "comments_avg" => 7.25,
        "contributors_count" => 45,
        "dependants_count" => 1845,
        "forks_count" => 105,
        "last_question_date_int" => 1500596485,
        "post_score_sum" => 21,
        "posts_count" => 8,
        "questions_count" => 84,
        "questions_resolved_percent" => 40.48.to_d,
        "stargazers_count" => 576,
        "total_downloads_count" => 177846841,
        "users_commenting_issues_count" => 120,
        "users_commenting_pr_count" => 59,
        "users_creating_issues_count" => 82,
        "users_creating_pr_count" => 62,
        "users_involved_count" => 804,
        "users_involved_no_stars_count" => 228,
        "watchers_count" => 28,
      })
    end

    it do
      expect(projectA.agility.quarters.last_year_as_hash).to eq({
        "commits" => 10.0,
        "issues_actual_count" => 4.0,
        "issues_all_count" => 5.0,
        "issues_closed_percent" => 100.0,
        "issues_processed_in_avg" => 91.0,
        "issues_processed_in_median" => 49.0,
        "pr_actual_count" => 1.0,
        "pr_all_count" => 4.0,
        "pr_closed_percent" => 100.0,
        "pr_processed_in_avg" => 43.0,
        "pr_processed_in_median" => 5.0,
        "releases_count" => 1.0,
      })
    end
    it do
      expect(projectA.agility.total.metrics_to_hash).to eq({
        "commits_count_since_last_release_count" => 5,
        "first_issue_date_int" => 1276899144,
        "first_pr_date_int" => 1287453975,
        "issues_all_count" => 97,
        "issues_closed_percent" => 98.97.to_d,
        "issues_non_owner_percent" => 100.0.to_d,
        "issues_processed_in_avg" => 48,
        "issues_processed_in_median" => 6,
        "issues_with_contrib_comments_percent" => 84.54.to_d,
        "last_changed" => 1509399446,
        "last_issue_date_int" => 1509399446,
        "last_pr_date_int" => 1506821604,
        "last_release_date_int" => 1504569600,
        "life_period" => 232500302,
        "pr_all_count" => 84,
        "pr_closed_percent" => 98.81.to_d,
        "pr_non_owner_percent" => 100.0.to_d,
        "pr_processed_in_avg" => 47,
        "pr_processed_in_median" => 16,
        "pr_with_contrib_comments_percent" => 84.52.to_d,
        "releases_count" => 56,
        "stale_branches_count" => 5,
      })
    end

    it do
      expect(projectB.community.quarters.last_year_as_hash).to eq({
        "answers_avg" => 1.1,
        "authors_count" => 67.0,
        "comments_avg" => 7.16,
        "forks_count" => 72.0,
        "post_score_sum" => 412.0,
        "posts_count" => 77.0,
        "question_score_sum" => 240.0,
        "question_view_sum" => 86248.0,
        "questioner_rep_median" => 82.0,
        "questioners_count" => 448.0,
        "questions_count" => 511.0,
        "questions_resolved_percent" => 50.88,
        "stargazers_count" => 356.0,
        "total_downloads_count" => 49256134.0,
        "users_commenting_issues_count" => 27.0,
        "users_commenting_pr_count" => 19.0,
        "users_creating_issues_count" => 26.0,
        "users_creating_pr_count" => 19.0,
        "users_involved_count" => 457.0,
        "users_involved_no_stars_count" => 101.0,
      })
    end

    it do
      expect(projectB.community.total.metrics_to_hash).to eq({
        "authors_count" => 285,
        "comments_avg" => 5.92,
        "contributors_count" => 167,
        "dependants_count" => 58645,
        "forks_count" => 426,
        "last_question_date_int" => 1509668298,
        "post_score_sum" => 2003,
        "posts_count" => 353,
        "questions_count" => 5625,
        "questions_resolved_percent" => 56.28.to_d,
        "stargazers_count" => 1095,
        "total_downloads_count" => 174990627,
        "users_commenting_issues_count" => 96,
        "users_commenting_pr_count" => 54,
        "users_creating_issues_count" => 86,
        "users_creating_pr_count" => 80,
        "users_involved_count" => 1672,
        "users_involved_no_stars_count" => 577,
        "watchers_count" => 76,
      })
    end

    it do
      expect(projectB.agility.quarters.last_year_as_hash).to eq({
        "commits" => 73.0,
        "issues_actual_count" => 30.0,
        "issues_all_count" => 46.0,
        "issues_closed_percent" => 39.13,
        "issues_processed_in_avg" => 86.0,
        "issues_processed_in_median" => 1.0,
        "pr_actual_count" => 16.0,
        "pr_all_count" => 41.0,
        "pr_closed_percent" => 87.8,
        "pr_processed_in_avg" => 61.0,
        "pr_processed_in_median" => 3.0,
        "releases_count" => 3.0,
      })
    end
    it do
      expect(projectB.agility.total.metrics_to_hash).to eq({
        "commits_count_since_last_release_count" => 5,
        "first_issue_date_int" => 1417051089,
        "first_pr_date_int" => 1401383556,
        "issues_all_count" => 95,
        "issues_closed_percent" => 70.53.to_d,
        "issues_non_owner_percent" => 100.0.to_d,
        "issues_processed_in_avg" => 67,
        "issues_processed_in_median" => 3,
        "issues_with_contrib_comments_percent" => 73.68.to_d,
        "last_changed" => 1508894198,
        "last_issue_date_int" => 1508894198,
        "last_pr_date_int" => 1508413971,
        "last_release_date_int" => 1508889600,
        "life_period" => 107510642,
        "pr_all_count" => 136,
        "pr_closed_percent" => 97.06.to_d,
        "pr_non_owner_percent" => 100.0.to_d,
        "pr_processed_in_avg" => 130,
        "pr_processed_in_median" => 66,
        "pr_with_contrib_comments_percent" => 65.44.to_d,
        "releases_count" => 97,
        "stale_branches_count" => 3,
      })
    end

    it do
      expect(projectC.community.quarters.last_year_as_hash).to eq({
        "answers_avg" => 1.0,
        "authors_count" => 3.0,
        "comments_avg" => 11.0,
        "forks_count" => 42.0,
        "post_score_sum" => 70.0,
        "posts_count" => 3.0,
        "question_score_sum" => 2.0,
        "question_view_sum" => 176.0,
        "questioner_rep_median" => 157.0,
        "questioners_count" => 2.0,
        "questions_count" => 2.0,
        "questions_resolved_percent" => 100.0,
        "stargazers_count" => 628.0,
        "total_downloads_count" => 525718.0,
        "users_commenting_issues_count" => 8.0,
        "users_commenting_pr_count" => 12.0,
        "users_creating_issues_count" => 5.0,
        "users_creating_pr_count" => 9.0,
        "users_involved_count" => 683.0,
        "users_involved_no_stars_count" => 55.0,
      })
    end

    it do
      expect(projectC.community.total.metrics_to_hash).to eq({
        "authors_count" => 6,
        "comments_avg" => 22.17,
        "contributors_count" => 22,
        "dependants_count" => 0,
        "forks_count" => 131,
        "last_question_date_int" => 1489848783,
        "post_score_sum" => 124,
        "posts_count" => 6,
        "questions_count" => 6,
        "questions_resolved_percent" => 66.67.to_d,
        "stargazers_count" => 4255,
        "total_downloads_count" => 735279,
        "users_commenting_issues_count" => 27,
        "users_commenting_pr_count" => 40,
        "users_creating_issues_count" => 21,
        "users_creating_pr_count" => 30,
        "users_involved_count" => 4437,
        "users_involved_no_stars_count" => 182,
        "watchers_count" => 111,
      })
    end

    it do
      expect(projectC.agility.quarters.last_year_as_hash).to eq({
        "commits" => 9.0,
        "issues_actual_count" => 7.0,
        "issues_all_count" => 9.0,
        "issues_closed_percent" => 55.56,
        "issues_processed_in_avg" => 353.0,
        "issues_processed_in_median" => 476.0,
        "pr_actual_count" => 7.0,
        "pr_all_count" => 16.0,
        "pr_closed_percent" => 93.75,
        "pr_processed_in_avg" => 145.0,
        "pr_processed_in_median" => 36.0,
        "releases_count" => 1.0,
      })
    end
    it do
      expect(projectC.agility.total.metrics_to_hash).to eq({
        "commits_count_since_last_release_count" => 2,
        "first_issue_date_int" => 1391636912,
        "first_pr_date_int" => 1391739149,
        "issues_all_count" => 24,
        "issues_closed_percent" => 83.33.to_d,
        "issues_non_owner_percent" => 100.0.to_d,
        "issues_processed_in_avg" => 105,
        "issues_processed_in_median" => 21,
        "issues_with_contrib_comments_percent" => 70.83.to_d,
        "last_changed" => 1506593931,
        "last_issue_date_int" => 1503378071,
        "last_pr_date_int" => 1506593931,
        "last_release_date_int" => 1503964800,
        "life_period" => 114957019,
        "pr_all_count" => 49,
        "pr_closed_percent" => 97.96.to_d,
        "pr_non_owner_percent" => 100.0.to_d,
        "pr_processed_in_avg" => 91,
        "pr_processed_in_median" => 18,
        "pr_with_contrib_comments_percent" => 81.63.to_d,
        "releases_count" => 7,
        "stale_branches_count" => 1,
      })
    end

    it do
      expect(projectD.community.quarters.last_year_as_hash).to eq({
        "answers_avg" => 0.0,
        "authors_count" => 0.0,
        "comments_avg" => 0.0,
        "forks_count" => 9.0,
        "post_score_sum" => 0.0,
        "posts_count" => 0.0,
        "question_score_sum" => 0.0,
        "question_view_sum" => 0.0,
        "questioner_rep_median" => 0.0,
        "questioners_count" => 0.0,
        "questions_count" => 0.0,
        "questions_resolved_percent" => 0.0,
        "stargazers_count" => 37.0,
        "total_downloads_count" => 11558.0,
        "users_commenting_issues_count" => 7.0,
        "users_commenting_pr_count" => 5.0,
        "users_creating_issues_count" => 3.0,
        "users_creating_pr_count" => 4.0,
        "users_involved_count" => 53.0,
        "users_involved_no_stars_count" => 16.0,
      })
    end

    it do
      expect(projectD.community.total.metrics_to_hash).to eq({
        "authors_count" => 0,
        "comments_avg" => 0.0,
        "contributors_count" => 11,
        "dependants_count" => 1,
        "forks_count" => 16,
        "last_question_date_int" => 0,
        "post_score_sum" => 0,
        "posts_count" => 0,
        "questions_count" => 0,
        "questions_resolved_percent" => 0,
        "stargazers_count" => 171,
        "total_downloads_count" => 15708,
        "users_commenting_issues_count" => 10,
        "users_commenting_pr_count" => 6,
        "users_creating_issues_count" => 4,
        "users_creating_pr_count" => 11,
        "users_involved_count" => 199,
        "users_involved_no_stars_count" => 28,
        "watchers_count" => 28,
      })
    end

    it do
      expect(projectD.agility.quarters.last_year_as_hash).to eq({
        "commits" => 33.0,
        "issues_actual_count" => 15.0,
        "issues_all_count" => 15.0,
        "issues_closed_percent" => 46.67,
        "issues_processed_in_avg" => 357.0,
        "issues_processed_in_median" => 447.0,
        "pr_actual_count" => 0.0,
        "pr_all_count" => 5.0,
        "pr_closed_percent" => 100.0,
        "pr_processed_in_avg" => 12.0,
        "pr_processed_in_median" => 14.0,
        "releases_count" => 3.0,
      })
    end
    it do
      expect(projectD.agility.total.metrics_to_hash).to eq({
        "commits_count_since_last_release_count" => 3,
        "first_issue_date_int" => 1446548597,
        "first_pr_date_int" => 1446407305,
        "issues_all_count" => 17,
        "issues_closed_percent" => 52.94.to_d,
        "issues_non_owner_percent" => 100.0.to_d,
        "issues_processed_in_avg" => 294,
        "issues_processed_in_median" => 267,
        "issues_with_contrib_comments_percent" => 64.71.to_d,
        "last_changed" => 1496140365,
        "last_issue_date_int" => 1493203392,
        "last_pr_date_int" => 1496140365,
        "last_release_date_int" => 1500940800,
        "life_period" => 49733060,
        "pr_all_count" => 27,
        "pr_closed_percent" => 100.0.to_d,
        "pr_non_owner_percent" => 100.0.to_d,
        "pr_processed_in_avg" => 21,
        "pr_processed_in_median" => 11,
        "pr_with_contrib_comments_percent" => 96.3.to_d,
        "releases_count" => 11,
        "stale_branches_count" => 2,
      })
    end

    it do
      expect(projectE.community.quarters.last_year_as_hash).to eq({
        "answers_avg" => 0.0,
        "authors_count" => 0.0,
        "comments_avg" => 0.0,
        "forks_count" => 0.0,
        "post_score_sum" => 0.0,
        "posts_count" => 0.0,
        "question_score_sum" => 0.0,
        "question_view_sum" => 0.0,
        "questioner_rep_median" => 0.0,
        "questioners_count" => 0.0,
        "questions_count" => 0.0,
        "questions_resolved_percent" => 0.0,
        "stargazers_count" => 2.0,
        "total_downloads_count" => 1819.0,
        "users_commenting_issues_count" => 0.0,
        "users_commenting_pr_count" => 0.0,
        "users_creating_issues_count" => 1.0,
        "users_creating_pr_count" => 0.0,
        "users_involved_count" => 3.0,
        "users_involved_no_stars_count" => 1.0
      })
    end

    it do
      expect(projectE.community.total.metrics_to_hash).to eq({
        "authors_count" => 0,
        "comments_avg" => 0.0,
        "contributors_count" => 1,
        "dependants_count" => 0,
        "forks_count" => 1,
        "last_question_date_int" => 0,
        "post_score_sum" => 0,
        "posts_count" => 0,
        "questions_count" => 0,
        "questions_resolved_percent" => 0,
        "stargazers_count" => 11,
        "total_downloads_count" => 5265,
        "users_commenting_issues_count" => 1,
        "users_commenting_pr_count" => 0,
        "users_creating_issues_count" => 1,
        "users_creating_pr_count" => 0,
        "users_involved_count" => 12,
        "users_involved_no_stars_count" => 1,
        "watchers_count" => 3,
      })
    end

    it do
      expect(projectE.agility.quarters.last_year_as_hash).to eq({
        "commits" => 0.0,
        "issues_actual_count" => 1.0,
        "issues_all_count" => 2.0,
        "issues_closed_percent" => 0.0,
        "issues_processed_in_avg" => 1826.0,
        "issues_processed_in_median" => 1826.0,
        "pr_actual_count" => 0.0,
        "pr_all_count" => 0.0,
        "pr_closed_percent" => 0.0,
        "pr_processed_in_avg" => 1826.0,
        "pr_processed_in_median" => 1826.0,
        "releases_count" => 0.0,
      })
    end
    it do
      expect(projectE.agility.total.metrics_to_hash).to eq({
        "commits_count_since_last_release_count" => 5,
        "first_issue_date_int" => 1455622969,
        "first_pr_date_int" => 0,
        "issues_all_count" => 3,
        "issues_closed_percent" => 33.33.to_d,
        "issues_non_owner_percent" => 0.0.to_d,
        "issues_processed_in_avg" => 44,
        "issues_processed_in_median" => 44,
        "issues_with_contrib_comments_percent" => 33.33.to_d,
        "last_changed" => 1488034862,
        "last_issue_date_int" => 1488034862,
        "last_pr_date_int" => 0,
        "last_release_date_int" => 1456617600,
        "life_period" => 32411893,
        "pr_all_count" => 0,
        "pr_closed_percent" => 0,
        "pr_non_owner_percent" => 0,
        "pr_processed_in_avg" => 0,
        "pr_processed_in_median" => 0,
        "pr_with_contrib_comments_percent" => 0,
        "releases_count" => 6,
        "stale_branches_count" => 1,
      })
    end
  end
end
