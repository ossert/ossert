require 'spec_helper'

describe Ossert do
  describe 'common behaviour' do
    let(:projectA) { Ossert::Project.load_by_name(@A_project) }
    let(:projectB) { Ossert::Project.load_by_name(@B_project) }
    let(:projectC) { Ossert::Project.load_by_name(@C_project) }
    let(:projectD) { Ossert::Project.load_by_name(@D_project) }
    let(:projectE) { Ossert::Project.load_by_name(@E_project) }

    let(:project_A_time_range) do
      [Date.parse('19/10/1996'), Date.parse('19/10/2016')]
    end

    it { expect(Ossert::Project.load_by_name('Not Exists')).to be_nil }
    it do
      expect(projectA.prepare_time_bounds!).to eq(project_A_time_range)
    end

    context 'when classifiers are ready' do
      before { Ossert::Classifiers.train }

      let(:grades_A) do
        {popularity: 'A', maintenance: 'A', maturity: 'A'}
      end
      let(:grades_B) do
        {popularity: 'A', maintenance: 'B', maturity: 'A'}
      end
      let(:grades_C) do
        {popularity: 'A', maintenance: 'C', maturity: 'C'}
      end
      let(:grades_D) do
        {popularity: 'D', maintenance: 'A', maturity: 'D'}
      end
      let(:grades_E) do
        {popularity: 'E', maintenance: 'E', maturity: 'E'}
      end

      it do
        expect(projectA.grade_by_classifier).to eq(grades_A)
        expect(projectB.grade_by_classifier).to eq(grades_B)
        expect(projectC.grade_by_classifier).to eq(grades_C)
        expect(projectD.grade_by_classifier).to eq(grades_D)
        expect(projectE.grade_by_classifier).to eq(grades_E)
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
