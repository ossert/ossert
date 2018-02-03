# frozen_string_literal: true
require 'spec_helper'
require 'pry'

describe Ossert do
  let(:projectA) { Ossert::Project.load_by_name(@a_project) }
  let(:projectB) { Ossert::Project.load_by_name(@b_project) }
  let(:projectC) { Ossert::Project.load_by_name(@c_project) }
  let(:projectD) { Ossert::Project.load_by_name(@d_project) }
  let(:projectE) { Ossert::Project.load_by_name(@e_project) }

  describe 'common behaviour' do
    let(:no_github_project) { Ossert::Project.load_by_name(@no_github_project) }
    let(:github_not_found_project) { Ossert::Project.load_by_name(@github_not_found_project) }

    it { expect(no_github_project).to be_without_github_data }
    it { expect(github_not_found_project).to be_without_github_data }

    let(:project_A_time_range) do
      [Date.parse('01/04/2010'), Date.parse('01/10/2017')]
    end

    it { expect(Ossert::Project.load_by_name('Not Exists')).to be_nil }
    it do
      expect(projectA.prepare_time_bounds!).to eq(project_A_time_range)
    end

    context 'when classifiers are ready' do
      before { Ossert::Classifiers.train }

      let(:grades_A) do
        { popularity: 'C', maintenance: 'B', maturity: 'C' }
      end
      let(:grades_B) do
        { popularity: 'A', maintenance: 'B', maturity: 'A' }
      end
      let(:grades_C) do
        { popularity: 'C', maintenance: 'C', maturity: 'C' }
      end
      let(:grades_D) do
        { popularity: 'D', maintenance: 'B', maturity: 'D' }
      end
      let(:grades_E) do
        { popularity: 'E', maintenance: 'E', maturity: 'E' }
      end

      it do
        expect(projectA.grade_by_classifier).to eq(grades_A)
        expect(projectB.grade_by_classifier).to eq(grades_B)
        expect(projectC.grade_by_classifier).to eq(grades_C)
        expect(projectD.grade_by_classifier).to eq(grades_D)
        expect(projectE.grade_by_classifier).to eq(grades_E)
      end

      context 'when non default last year offset' do
        it { expect(projectA.agility.quarters.last_year_as_hash(3)).to be_a_kind_of(Hash) }
        it { expect(projectA.agility.quarters.last_year_as_hash(5)).to be_a_kind_of(Hash) }
        it { expect(projectA.agility.quarters.last_year_data(3)).to be_a_kind_of(Array) }
        it { expect(projectA.agility.quarters.last_year_data(5)).to be_a_kind_of(Array) }
      end

      context 'when project is decorated' do
        let(:project) { projectE.decorated }
        let(:call_references) do
          project.preview_reference_values_for(metric_name, section)
        end

        describe '#tooltip_data' do
          let(:tooltip_data) { projectB.decorated.tooltip_data('issues_all_count') }

          it do
            expect(tooltip_data).to eq(
              :description => "Total number of issues, with any status",
              :ranks => [{:type=>"a", :quarter=>"&gt;&nbsp; 2", :total=>"&gt;&nbsp; 97", :year=>"&gt;&nbsp; 5"},
                         # Strange behavior with B values higher then A. Do we need to change initial projects list?
                         {:type=>"b", :quarter=>"&gt;&nbsp; 30", :total=>"&gt;&nbsp; 95", :year=>"&gt;&nbsp; 46"},
                         {:type=>"c", :quarter=>"&gt;&nbsp; 8", :total=>"&gt;&nbsp; 24", :year=>"&gt;&nbsp; 9"},
                         {:type=>"d", :quarter=>"&gt;&nbsp; 8", :total=>"&gt;&nbsp; 17", :year=>"&gt;&nbsp; 15"},
                         {:type=>"e", :quarter=>"&gt;&nbsp; 0", :total=>"&gt;&nbsp; 3", :year=>"&gt;&nbsp; 2"}],
              :title => "Number of Issues"
            )
          end
        end

        describe '#metric_preview' do
          context 'when metric is life_period' do
            let(:preview) { project.metric_preview('life_period') }
            let(:other_preview) { projectB.decorated.metric_preview('life_period') }

            it do
              expect(preview[:total_mark]).to eq('e')
              expect(preview[:total_text]).to eq('1+ years&nbsp;E')
              expect(preview[:total_val]).to eq(32411893.0)
              expect(other_preview[:total_mark]).to eq('b')
              expect(other_preview[:total_text]).to eq('3+ years&nbsp;B')
              expect(other_preview[:total_val]).to eq(107510642.0)
            end
          end

          context 'when metric is issues_processed_in_avg' do
            let(:preview) { project.metric_preview('issues_processed_in_avg') }

            it do
              expect(preview[:last_year_mark]).to eq('e')
              expect(preview[:last_year_text]).to eq('N/A&nbsp;E')
              expect(preview[:last_year_val]).to eq(1826.0)
              expect(preview[:total_mark]).to eq('b')
              expect(preview[:total_text]).to eq('~1 month&nbsp;B')
              expect(preview[:total_val]).to eq(44.0)
            end
          end

          context 'when metric is issues_processed_in_median' do
            let(:preview) { project.metric_preview('issues_processed_in_median') }

            it do
              expect(preview[:last_year_mark]).to eq('e')
              expect(preview[:last_year_text]).to eq('N/A&nbsp;E')
              expect(preview[:last_year_val]).to eq(1826.0)
              expect(preview[:total_mark]).to eq('b')
              expect(preview[:total_text]).to eq('~1 month&nbsp;B')
              expect(preview[:total_val]).to eq(44.0)
            end
          end
        end

        describe '#reference_values_per_grade' do
          context 'when agility_total metric given' do
            let(:section) { :agility_total }

            context 'when growing metric given' do
              let(:metric_name) { 'issues_all_count' }

              it do
                expect(call_references).to eq('A' => '> 97',
                                              'B' => '> 95',
                                              'C' => '> 24',
                                              'D' => '> 17',
                                              'E' => '> 3')
              end
            end

            context 'when lowering metric given' do
              let(:metric_name) { 'stale_branches_count' }

              it do
                expect(call_references).to eq('A' => '< 3',
                                              'B' => '< 6',
                                              'C' => '< 9',
                                              'D' => '< 12',
                                              'E' => '< 15')
              end
            end
          end
        end
      end
    end

    context 'when classifiers are not ready' do
      before { Ossert::Classifiers::Growing.all = nil }

      it do
        expect { projectA.grade_by_classifier }.to(
          raise_error(StandardError)
        )
      end
    end
  end

  describe 'Ossert::Classifiers::Cluster' do
    before do
      Ossert::Classifiers::Cluster.train_all_sections_thresholds
      cluster_classifier.train
    end
    let(:cluster_classifier) { Ossert::Classifiers::Cluster.current }
    let(:cluster_ref_values) { cluster_classifier.reference_values_per_grade }

    it { expect(cluster_ref_values[:agility_total]['pr_closed_percent'].keys).to eq(Ossert::Classifiers::GRADES) }
    it { expect(projectE.grade_by_cluster).to eq(:popularity=>nil, :maintenance=>"E", :maturity=>"E") }
  end

  describe 'Ossert::Presenters::Project' do
    let(:decorated_project) { projectC.decorated }
    before { Ossert::Classifiers.train }
    it do
      expect(Ossert::Presenters::Project.preview_for(projectB)[:analysis]).to eq(
        :popularity=>"a",
        :maintenance=>"b",
        :maturity=>"a"
      )
    end
    it do
      expect(decorated_project.agility_quarter(Time.parse('01.01.2017'))).to eq({
        "Average Issue Processing Time" => "  ~11 days&nbsp;A <> ~-58 months\n",
        "Average Pull Request Processing Time" => "  ~4 months&nbsp;E <> ~3 months\n",
        "Issues Closed, %" => "  13%&nbsp;E <> +12%\n",
        "Median Issue Processing Time" => "  ~11 days&nbsp;A <> ~-58 months\n",
        "Median Pull Request Processing Time" => "  ~3 months&nbsp;E <> ~3 months\n",
        "Number of Commits Made" => "  4&nbsp;D <> +4\n",
        "Number of Issues" => "  8&nbsp;A <> +2\n",
        "Number of Legacy Issues" => "  6&nbsp;A <> +2\n",
        "Number of Legacy Pull Requests" => "  5&nbsp;A <> 0\n",
        "Number of Pull Requests" => "  8&nbsp;A <> 0\n",
        "Number of Releases" => "  0&nbsp;E <> 0\n",
        "Pull Requests Closed, %" => "  50%&nbsp;D <> +13%\n",
      })
    end
    it do
      expect(decorated_project.community_quarter(Time.parse('01.01.2017'))).to eq({
        "Average Number of Answers" => "  1&nbsp;A <> 0\n",
        "Average Number of Comments" => "  6&nbsp;B <> +6\n",
        "Median Questioner Reputation" => "  181&nbsp;A <> +47\n",
        "Number of Authors" => "  1&nbsp;D <> +1\n",
        "Number of Downloads" => "  102,299&nbsp;D <> +39,597\n",
        "Number of Forks" => "  8&nbsp;A <> -2\n",
        "Number of Questioners" => "  1&nbsp;C <> 0\n",
        "Number of Questions" => "  1&nbsp;C <> 0\n",
        "Number of Stargazers" => "  223&nbsp;A <> +46\n",
        "Number of Total Users Involved" => "  239&nbsp;A <> +48\n",
        "Number of Users Commenting Issues" => "  1&nbsp;A <> -1\n",
        "Number of Users Commenting Pull Requests" => "  8&nbsp;A <> +4\n",
        "Number of Users Creating Issues" => "  2&nbsp;A <> 0\n",
        "Number of Users Creating Pull Requests" => "  3&nbsp;A <> 0\n",
        "Number of Users Involved without Stargazers" => "  16&nbsp;A <> +2\n",
        "Number of posts" => "  1&nbsp;D <> +1\n",
        "Resolved Questions, %" => "  100%&nbsp;A <> 0%\n",
        "Sum of Post Scores" => "  19&nbsp;D <> +19\n",
        "Sum of Question Scores" => "  0&nbsp;E <> -2\n",
        "Sum of Question Views" => "  51&nbsp;D <> -74\n",
      })
    end
    it do
      expect(decorated_project.agility_quarter_values(Time.parse('01.01.2017'))).to eq({
        "commits" => 4,
        "issues_actual_count" => 6,
        "issues_all_count" => 8,
        "issues_closed_percent" => 12,
        "issues_processed_in_avg" => 11,
        "issues_processed_in_median" => 11,
        "pr_actual_count" => 5,
        "pr_all_count" => 8,
        "pr_closed_percent" => 50,
        "pr_processed_in_avg" => 138,
        "pr_processed_in_median" => 117,
        "releases_count" => 0,
      })
    end
    it do
      expect(decorated_project.community_quarter_values(Time.parse('01.01.2017'))).to eq({
        "answers_avg" => 1,
        "authors_count" => 1,
        "comments_avg" => 6,
        "forks_count" => 8,
        "post_score_sum" => 19,
        "posts_count" => 1,
        "question_score_sum" => 0,
        "question_view_sum" => 51,
        "questioner_rep_median" => 181,
        "questioners_count" => 1,
        "questions_count" => 1,
        "questions_resolved_percent" => 100,
        "stargazers_count" => 223,
        "total_downloads_count" => 102299,
        "users_commenting_issues_count" => 1,
        "users_commenting_pr_count" => 8,
        "users_creating_issues_count" => 2,
        "users_creating_pr_count" => 3,
        "users_involved_count" => 239,
        "users_involved_no_stars_count" => 16,
      })
    end
  end

  describe 'Ossert::Classifiers::DecisionTree' do
    before { Ossert::Classifiers.train }
    it do
      expect(projectE.analyze_by_decisision_tree).to eq(
        :agility => {:total=>"ClassE", :last_year=>"ClassE"},
        :community => {:total=>"ClassE", :last_year=>"ClassE"},
      )
    end
  end

  describe 'Ossert::Reference' do
    before do
      VCR.use_cassette 'fetch_b_reference' do
        reference.prepare_projects!
        reference.project_names = Set.new(reference.project_names.to_a.last(1))
        reference.project_names << projectB.name

        Ossert::Reference.process_references(reference)
      end
    end
    let(:reference) { Ossert::Reference::ClassB.new(20, [70]) }
    let(:last_ref_project) { Ossert::Project.load_by_name(reference.project_names.to_a.last) }

    it { expect(last_ref_project.reference).to eq 'ClassB' }
  end

  describe 'Ossert::Saveable' do
    let(:invalid_project) do
      projectE.github_alias = nil
      projectE
    end

    it { expect { invalid_project.dump }.to raise_error(Ossert::Saveable::RecordInvalid) }
    it { expect { projectD.dump_attribute(:tratata_data) }.to raise_error(KeyError) }
    it { expect { projectD.dump_attribute(:agility_total_data) }.not_to raise_error }
    it { expect { projectD.dump_attribute(:community_total_data) }.not_to raise_error }
    it { expect { projectD.dump_attribute(:agility_quarters_data) }.not_to raise_error }
    it { expect { projectD.dump_attribute(:community_quarters_data) }.not_to raise_error }
    it { expect(Ossert::Project.random_top.map(&:name)).to match_array([@a_project, @b_project, @c_project]) }
    it { expect { Ossert::Project.random }.not_to raise_error }
    it { expect(Ossert::Project.load_later_than(0)).not_to be_empty }

    context 'when NameException exists' do
      before { NameException.create(name: projectE.name, github_name: 'pow-wow/exception') }
      after { NameException.where(name: projectE.name).delete }
      it do
        expect(Ossert::Project.find_by_name(projectE.name).github_alias).to eq('pow-wow/exception')
      end
    end
  end

  describe 'Ossert::Workers::FetchBestgemsPage' do
    before { allow(Ossert::Project).to receive(:fetch_all) }
    before { allow(Ossert).to receive(:init) }

    describe 'ForkProcessing' do
      class SumInFork
        include Ossert::Workers::ForkProcessing

        attr_reader :result

        def initialize
          @result = nil
        end

        def sum(a, b)
          process_in_fork(force: true) { @result = a + b }
        end
      end
      # not working... need to figure out why
    end

    describe 'FetchBestgemsPage' do
      it do
        VCR.use_cassette 'fetch_bestgems_page' do
          Ossert::Workers::FetchBestgemsPage.new.perform(1)
        end
      end
    end

    describe 'Fetch' do
      it { Ossert::Workers::Fetch.new.perform('rack') }
    end

    describe 'PartialFetch' do
      it do
        VCR.use_cassette 'fetch_partial_rubygems' do
          Ossert::Workers::PartialFetch.new.perform('Rubygems', projectE.name)
        end
      end
    end

    describe 'PartialRefreshFetch' do
      it { Ossert::Workers::PartialRefreshFetch.new.perform('Bestgems') }
    end

    describe 'RefreshFetch' do
      it { Ossert::Workers::RefreshFetch.new.perform }
    end
  end

  describe 'Ossert::Fetch' do
    let(:project) { Ossert::Project.load_by_name(project_name) }
    let(:project_name) { projectD.name }

    before do
      VCR.use_cassette 'fetch_a_rubygems' do
        Ossert::Project.update_with_one_fetcher(Ossert::Fetch::Rubygems, project_name)
      end
    end

    it { expect(project.github_alias).to eq 'dry-rb/dry-web' }
  end
end
