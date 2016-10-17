require 'ossert/classifiers/decision_tree'
require 'ossert/classifiers/growing'

module Ossert
  module Classifiers
    def train
      projects_by_reference = Ossert::Project.projects_by_reference
      Growing.new(projects_by_reference).train
      # Stale. Very untrusty
      # DecisionTree.new(projects_by_reference).train
    end
    module_function :train
  end
end
