require 'ossert/classifiers/decision_tree'
require 'ossert/classifiers/growing'

module Ossert
  module Classifiers
    def train
      Growing.for_current_projects.train
      DecisionTree.for_current_projects.train
    end
    module_function :train
  end
end
