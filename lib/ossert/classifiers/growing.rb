# frozen_string_literal: true
require 'ossert/classifiers/growing/classifier'

module Ossert
  module Classifiers
    class Growing
      GRADES = %w(
        ClassA
        ClassB
        ClassC
        ClassD
        ClassE
      ).freeze

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
        (self.class.all ||= []) << self
      end

      attr_reader :train_group
      attr_reader :agility_total_classifier, :community_total_classifier,
                  :agility_quarter_classifier, :community_quarter_classifier,
                  :agility_last_year_classifier, :community_last_year_classifier

      def ready?
        agility_total_classifier.keys == GRADES && community_total_classifier.keys == GRADES
      end

      def reference_values_per_grade
        {
          agility_total: classifier_to_metrics_per_grade(agility_total_classifier),
          agility_quarter: classifier_to_metrics_per_grade(agility_quarter_classifier),
          agility_year: classifier_to_metrics_per_grade(agility_last_year_classifier),
          community_total: classifier_to_metrics_per_grade(community_total_classifier),
          community_quarter: classifier_to_metrics_per_grade(community_quarter_classifier),
          community_year: classifier_to_metrics_per_grade(community_last_year_classifier)
        }
      end

      def classifier_to_metrics_per_grade(classifier)
        classifier.each_with_object({}) do |(grade, metrics), res|
          metrics.each do |metric, value|
            (res[metric] ||= {})[grade] = value
          end
        end
      end

      def process_using(action, project, last_year_offset = 1)
        Check.send(action,
                   self.class.config,
                   project,
                   {
                     agility_total: agility_total_classifier,
                     community_total: community_total_classifier,
                     agility_last_year: agility_last_year_classifier,
                     community_last_year: community_last_year_classifier
                   },
                   last_year_offset)
      end

      def grade(*args)
        process_using(*args.unshift(:grade))
      end

      def check(*args)
        process_using(*args.unshift(:check))
      end

      def train
        classifiers_initializer = ClassifiersInitializer.load_or_create
        classifiers_initializer.run
        classifiers_initializer.classifiers.each do |name, classifier|
          instance_variable_set(
            "@#{name}_classifier",
            Classifier.new(classifier, self.class.config).train
          )
        end
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
          @classifiers = []
        end

        def load
          @classifiers = {}
          Ossert::Classifiers::METRICS.keys.each do |section|
            @classifiers[section] = JSON.parse(::Classifier[section.to_s].reference_values)
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
          Ossert::Classifiers::METRICS.keys.map { |type| [type, {}] }.to_h
        end

        def run
          return if @classifiers.present?

          @classifiers = GRADES.each_with_object(new_classifiers) do |grade, classifiers|
            @projects[grade].each do |project|
              Ossert::Classifiers::METRICS.each do |type, metrics|
                classifiers[type][grade] = merge_metrics(classifiers[type][grade].to_h, metrics.call(project))
              end
            end
          end

          save
        end
      end
    end
  end
end
