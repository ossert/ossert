# frozen_string_literal: true
require 'spec_helper'

describe Ossert do
  describe 'common behaviour' do
    let(:projectA) { Ossert::Project.load_by_name(@a_project) }
    let(:projectB) { Ossert::Project.load_by_name(@b_project) }
    let(:projectC) { Ossert::Project.load_by_name(@c_project) }
    let(:projectD) { Ossert::Project.load_by_name(@d_project) }
    let(:projectE) { Ossert::Project.load_by_name(@e_project) }
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
        { popularity: 'A', maintenance: 'A', maturity: 'A' }
      end
      let(:grades_B) do
        { popularity: 'A', maintenance: 'B', maturity: 'A' }
      end
      let(:grades_C) do
        { popularity: 'C', maintenance: 'C', maturity: 'C' }
      end
      let(:grades_D) do
        { popularity: 'D', maintenance: 'D', maturity: 'D' }
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

      it { expect(projectA.agility.quarters.last_year_as_hash).to be_a_kind_of(Hash) }
      it { expect(projectA.agility.quarters.last_year_as_hash(3)).to be_a_kind_of(Hash) }
      it { expect(projectA.agility.quarters.last_year_as_hash(5)).to be_a_kind_of(Hash) }
      it { expect(projectA.agility.quarters.last_year_data).to be_a_kind_of(Array) }
      it { expect(projectA.agility.quarters.last_year_data(3)).to be_a_kind_of(Array) }
      it { expect(projectA.agility.quarters.last_year_data(5)).to be_a_kind_of(Array) }

      context 'when project is decorated' do
        let(:project) { projectE.decorated }
        let(:call_references) do
          project.preview_reference_values_for(metric_name, section)
        end

        describe '#metric_preview' do
          let(:preview) { project.metric_preview('issues_processed_in_avg') }

          it do
            expect(preview[:last_year_mark]).to eq('e')
            expect(preview[:last_year_val]).to eq('N/A&nbsp;E')
            expect(preview[:total_mark]).to eq('b')
            expect(preview[:total_val]).to eq('~1 month&nbsp;B')
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
end
