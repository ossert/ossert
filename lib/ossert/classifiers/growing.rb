# frozen_string_literal: true
require 'ossert/classifiers/growing/classifier'

module Ossert
  module Classifiers
    class Growing < Base
      class << self
        attr_accessor :all

        def current
          all.last
        end

        def config
          @config ||= Settings['classifiers_growth']
        end
      end

      def initialize
        super
        (self.class.all ||= []) << self
      end

      def train
        classifiers_initializer = ClassifiersInitializer.load_or_create
        classifiers_initializer.run
        @classifiers = classifiers_initializer.classifiers.map do |name, classifier|
           Classifier.new(classifier, self.class.config, name).train
        end.to_h
      end

      class ClassifiersInitializer
        def self.load_or_create
          if ::Classifier.actual?
            new.load
          else
            new(Project.projects_by_reference)
          end
        end

        attr_reader :classifiers

        def initialize(grouped_projects = nil)
          @projects = grouped_projects
          @classifiers = {}
        end

        def load
          @classifiers = {}
          CLASSIFIERS.each do |classifier_name|
            @classifiers[classifier_name] = JSON.parse(::Classifier[classifier_name.to_s].reference_values)
          end
          self
        end

        def merge_metrics(storage, metrics)
          metrics.each do |metric, value|
            storage.store(
              metric.to_s,
              storage[metric.to_s].to_a << value.to_f
            )
          end
          storage
        end

        def save
          ::Classifier.dataset.delete

          @classifiers.each do |section, reference_values|
            ::Classifier.create(
              section: section.to_s,
              reference_values: JSON.generate(reference_values)
            )
          end
        end

        def new_classifiers
          CLASSIFIERS.map { |classifier_name| [classifier_name, {}] }.to_h
        end

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
