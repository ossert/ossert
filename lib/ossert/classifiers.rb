# frozen_string_literal: true
require 'ossert/classifiers/decision_tree'
require 'ossert/classifiers/growing'

module Ossert
  module Classifiers
    def train
      Growing.new.train
      # Stale. Very untrusty
      # DecisionTree.new(projects_by_reference).train
    end
    module_function :train
  end
end
