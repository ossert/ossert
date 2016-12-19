# frozen_string_literal: true
require 'ossert/classifiers/decision_tree'
require 'ossert/classifiers/growing'
require 'ossert/classifiers/cluster'
require 'ossert/classifiers/check'

module Ossert
  module Classifiers
    SECTIONS = %i(agility community)
    PERIODS = %i(total quarter last_year)

    GRADES = %w(
      ClassA
      ClassB
      ClassC
      ClassD
      ClassE
    ).freeze
    REVERSED_GRADE = {
      'ClassA' => 'ClassE',
      'ClassB' => 'ClassD',
      'ClassC' => 'ClassC',
      'ClassD' => 'ClassB',
      'ClassE' => 'ClassA'
    }.freeze

    # Public: Map for metrics values accessors
    METRICS = {
      agility_total:       ->(project) { project.agility.total.metrics_to_hash           },
      agility_quarter:     ->(project) { project.agility.quarters.last.metrics_to_hash   },
      agility_last_year:   ->(project) { project.agility.quarters.last_year_as_hash      },
      community_total:     ->(project) { project.community.total.metrics_to_hash         },
      community_quarter:   ->(project) { project.community.quarters.last.metrics_to_hash },
      community_last_year: ->(project) { project.community.quarters.last_year_as_hash    }
    }.freeze

    # Public: Prepare classifiers.
    # It warms up classifiers upon existing data.
    def train
      Growing.new.train
      Cluster.current.train
      # Stale. Very untrusty
      # DecisionTree.new(projects_by_reference).train
    end
    module_function :train
  end
end
