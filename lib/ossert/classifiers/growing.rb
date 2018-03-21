# frozen_string_literal: true

require 'ossert/classifiers/growing/classifier'

module Ossert
  module Classifiers
    class Growing < Base
      class << self
        attr_accessor :all

        # Prepare and return growing classifier instance.
        # The last prepared growing classifier.
        #
        # @return [Ossert::Classifiers::Growing] initialized growing classifer
        def current
          all.last
        end

        # @return [Hash] the configuration of Growing classifier.
        def config
          @config ||= Settings['classifiers_growth']
        end
      end

      def initialize
        super
        (self.class.all ||= []) << self
      end

      # Run training process using current classifier state.
      #
      # @return [Hash<Symbol, Hash>] collection of classifiers for all combinations
      #   of data sections and periods.
      def train
        classifiers_initializer = ClassifiersInitializer.load_or_create
        classifiers_initializer.run
        @classifiers = classifiers_initializer.classifiers.map do |name, classifier|
          Classifier.new(classifier, self.class.config, name).train
        end.to_h
      end

      # Class for Growing classifier initialization
      class ClassifiersInitializer
        # Load or create classifier using stored state.
        #
        # @return [ClassifierInitializer] the prepared class instance.
        def self.load_or_create
          if ::Classifier.actual?
            new.load
          else
            new(Project.projects_by_reference)
          end
        end

        # @return [Hash<Symbol, Hash>] classifiers with their metrics data
        attr_reader :classifiers

        def initialize(grouped_projects = nil)
          @projects = grouped_projects
          @classifiers = {}
        end

        # Load classifiers state from storage
        #
        # @return [ClassifiersInitializer] the updated instance.
        def load
          @classifiers = {}
          CLASSIFIERS.each do |classifier_name|
            @classifiers[classifier_name] = JSON.parse(::Classifier[classifier_name.to_s].reference_values)
          end
          self
        end

        # Merge metric values for given storage and metrics.
        #
        # @param storage [Hash] which stores metric values
        # @param metrics [Array<String>] that are merged
        # @return not specified.
        def merge_metrics(storage, metrics)
          metrics.each do |metric, value|
            storage.store(
              metric.to_s,
              storage[metric.to_s].to_a << value.to_f
            )
          end
          storage
        end

        # Save current state of classifiers to storage.
        #
        # @return not specified.
        def save
          ::Classifier.dataset.delete

          @classifiers.each do |section, reference_values|
            ::Classifier.create(
              section: section.to_s,
              reference_values: JSON.generate(reference_values)
            )
          end
        end

        # Initialize data for all classifiers.
        #
        # @return not specified.
        def new_classifiers
          CLASSIFIERS.map { |classifier_name| [classifier_name, {}] }.to_h
        end

        # Collect data for classifiers using current state projects in storage.
        # By the way, saves classifiers to storage for future retrieval.
        #
        # @return not specified.
        def run
          return if @classifiers.present?

          @classifiers = GRADES.each_with_object(new_classifiers) do |grade, classifiers|
            @projects[grade].each do |project|
              SECTIONS.product(PERIODS).each do |section, period|
                metrics = project.data_for(section: section, period: period)
                classifier_name = "#{section}_#{period}".to_sym

                classifiers[classifier_name][grade] = merge_metrics(
                  classifiers[classifier_name][grade].to_h,
                  metrics
                )
              end
            end
          end

          save
        end
      end
    end
  end
end
