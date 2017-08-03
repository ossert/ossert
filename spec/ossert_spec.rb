# frozen_string_literal: true
require 'spec_helper'

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
      [Date.parse('01/04/2010'), Date.parse('01/10/2016')]
    end

    it { expect(Ossert::Project.load_by_name('Not Exists')).to be_nil }
    it do
      expect(projectA.prepare_time_bounds!).to eq(project_A_time_range)
    end

    context 'when classifiers are ready' do
      before { Ossert::Classifiers.train }

      let(:grades_A) do
        { popularity: 'B', maintenance: 'C', maturity: 'C' }
      end
      let(:grades_B) do
        { popularity: 'A', maintenance: 'B', maturity: 'A' }
      end
      let(:grades_C) do
        { popularity: 'C', maintenance: 'B', maturity: 'B' }
      end
      let(:grades_D) do
        { popularity: 'D', maintenance: 'C', maturity: 'D' }
      end
      let(:grades_E) do
        { popularity: 'E', maintenance: 'D', maturity: 'E' }
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
              :ranks => [{:type=>"a", :quarter=>"&gt;&nbsp; 1", :total=>"&gt;&nbsp; 92", :year=>"&gt;&nbsp; 8"},
                         # Strange behavior with B values higher then A. Do we need to change initial projects list?
                         {:type=>"b", :quarter=>"&gt;&nbsp; 27", :total=>"&gt;&nbsp; 68", :year=>"&gt;&nbsp; 51"},
                         {:type=>"c", :quarter=>"&gt;&nbsp; 4", :total=>"&gt;&nbsp; 19", :year=>"&gt;&nbsp; 14"},
                         {:type=>"d", :quarter=>"&gt;&nbsp; 8", :total=>"&gt;&nbsp; 10", :year=>"&gt;&nbsp; 10"},
                         {:type=>"e", :quarter=>"&gt;&nbsp; 0", :total=>"&gt;&nbsp; 2", :year=>"&gt;&nbsp; 2"}],
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
              expect(preview[:total_text]).to eq('Less than a year&nbsp;E')
              expect(preview[:total_val]).to eq(87828.0)
              expect(other_preview[:total_mark]).to eq('b')
              expect(other_preview[:total_text]).to eq('2+ years&nbsp;B')
              expect(other_preview[:total_val]).to eq(75673089.0)
            end
          end

          context 'when metric is issues_processed_in_avg' do
            let(:preview) { project.metric_preview('issues_processed_in_avg') }

            it do
              expect(preview[:last_year_mark]).to eq('b')
              expect(preview[:last_year_text]).to eq('~1 month&nbsp;B')
              expect(preview[:last_year_val]).to eq(44.0)
              expect(preview[:total_mark]).to eq('b')
              expect(preview[:total_text]).to eq('~1 month&nbsp;B')
              expect(preview[:total_val]).to eq(44.0)
            end
          end

          context 'when metric is issues_processed_in_median' do
            let(:preview) { project.metric_preview('issues_processed_in_median') }

            it do
              expect(preview[:last_year_mark]).to eq('b')
              expect(preview[:last_year_text]).to eq('~1 month&nbsp;B')
              expect(preview[:last_year_val]).to eq(44.0)
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
                expect(call_references).to eq('A' => '> 92',
                                              'B' => '> 68',
                                              'C' => '> 19',
                                              'D' => '> 10',
                                              'E' => '> 2')
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
    it { expect(projectE.grade_by_cluster).to eq(:popularity=>"E", :maintenance=>"E", :maturity=>"E") }
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
      expect(decorated_project.agility_quarter(Time.parse('01.01.2016'))).to eq({
        "Average Issue Processing Time" => "  ~24 days&nbsp;A <> ~-58 months\n",
        "Average Pull Request Processing Time" => "  ~17 days&nbsp;A <> ~4 days\n",
        "Issues Closed, %" => "  70%&nbsp;C <> +70%\n",
        "Median Issue Processing Time" => "  ~1 day&nbsp;A <> ~-58 months\n",
        "Median Pull Request Processing Time" => "  ~16 days&nbsp;A <> ~1 day\n",
        "Number of Commits Made" => "  11&nbsp;A <> +4\n",
        "Number of Issues" => "  10&nbsp;A <> +8\n",
        "Number of Legacy Issues" => "  2&nbsp;A <> +1\n",
        "Number of Legacy Pull Requests" => "  3&nbsp;A <> +3\n",
        "Number of Pull Requests" => "  13&nbsp;A <> +7\n",
        "Number of Releases" => "  1&nbsp;A <> +1\n",
        "Pull Requests Closed, %" => "  70%&nbsp;C <> +19%\n",
      })
    end
    it do
      expect(decorated_project.community_quarter(Time.parse('01.01.2016'))).to eq({
        "Average Number of Answers" => "  0&nbsp;E <> 0\n",
        "Median Questioner Reputation" => "  0&nbsp;E <> 0\n",
        "Number of Downloads" => "  15,435&nbsp;D <> +10,981\n",
        "Number of Forks" => "  51&nbsp;A <> +43\n",
        "Number of Stargazers" => "  2013&nbsp;A <> +1536\n",
        "Number of Total Users Involved" => "  2063&nbsp;A <> +1575\n",
        "Number of Users Commenting Issues" => "  7&nbsp;A <> +6\n",
        "Number of Users Commenting Pull Requests" => "  19&nbsp;A <> +13\n",
        "Number of Users Creating Issues" => "  6&nbsp;A <> +5\n",
        "Number of Users Creating Pull Requests" => "  5&nbsp;A <> 0\n",
        "Number of Users Involved without Stargazers" => "  50&nbsp;A <> +39\n",
        "Number of Questioners" => "  0&nbsp;D <> 0\n",
        "Number of Questions" => "  0&nbsp;C <> 0\n",
        "Resolved Questions, %" => "  0%&nbsp;A <> 0%\n",
        "Sum of Question Scores" => "  0&nbsp;E <> 0\n",
        "Sum of Question Views" => "  0&nbsp;E <> 0\n",
      })
    end
    it do
      expect(decorated_project.agility_quarter_values(Time.parse('01.01.2016'))).to eq({
        "commits" => 11,
        "issues_actual_count" => 2,
        "issues_all_count" => 10,
        "issues_closed_percent" => 70,
        "issues_processed_in_avg" => 24,
        "issues_processed_in_median" => 1,
        "pr_actual_count" => 3,
        "pr_all_count" => 13,
        "pr_closed_percent" => 69,
        "pr_processed_in_avg" => 17,
        "pr_processed_in_median" => 16,
        "releases_count" => 1
      })
    end
    it do
      expect(decorated_project.community_quarter_values(Time.parse('01.01.2016'))).to eq({
        "answers_avg" => 0,
        "forks_count" => 51,
        "question_score_sum" => 0,
        "question_view_sum" => 0,
        "questioner_rep_median" => 0,
        "questioners_count" => 0,
        "questions_count" => 0,
        "questions_resolved_percent" => 0,
        "stargazers_count" => 2013,
        "total_downloads_count" => 15435,
        "users_commenting_issues_count" => 7,
        "users_commenting_pr_count" => 19,
        "users_creating_issues_count" => 6,
        "users_creating_pr_count" => 5,
        "users_involved_count" => 2063,
        "users_involved_no_stars_count" => 50,
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
