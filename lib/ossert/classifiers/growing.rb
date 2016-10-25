require 'ossert/classifiers/growing/classifier'
require 'ossert/classifiers/growing/check'

module Ossert
  module Classifiers
    class Growing
      GRADES = %w(ClassA ClassB ClassC ClassD ClassE)

      class << self
        attr_accessor :all

        def current
          all.last
        end

        def config
          @config ||= Settings['classifiers']['growth']
        end
      end

      def initialize
        (self.class.all ||= []) << self
      end

      attr_reader :train_group
      attr_reader :agility_total_classifier, :community_total_classifier,
                  :agility_last_year_classifier, :community_last_year_classifier

      def ready?
        agility_total_classifier.keys == GRADES && community_total_classifier.keys == GRADES
      end

      def reference_values_per_grade
        to_metrics_per_grade = ->(classifier) {
          classifier.each_with_object({}) do |(grade, metrics), res|
            metrics.each do |metric, value|
              (res[metric] ||= {})[grade] = value
            end
          end
        }

        {
          agility_total: to_metrics_per_grade.(agility_total_classifier),
          agility_quarter: to_metrics_per_grade.(agility_last_year_classifier),
          agility_year: to_metrics_per_grade.(agility_last_year_classifier),
          community_total: to_metrics_per_grade.(community_total_classifier),
          community_quarter: to_metrics_per_grade.(community_last_year_classifier),
          community_year: to_metrics_per_grade.(community_last_year_classifier)
        }
      end

      def process_using(action, project, last_year_offset = 1)
        Check.send(action,
          self.class.config,
          project,
          {
            agility_total: agility_total_classifier,
            community_total: community_total_classifier,
            agility_last_year: agility_last_year_classifier,
            community_last_year: community_last_year_classifier,
          },
          last_year_offset
        )
      end

      def grade(*args)
        process_using(*args.unshift(:grade))
      end

      def check(*args)
        process_using(*args.unshift(:check))
      end

      def train
        classifiers = ClassifiersInitializer.load_or_create.run
        classifiers.each do |name, classifier|
          instance_variable_set(
            "@#{name}_classifier",
            Classifier.new(classifier, self.class.config).train
          )
        end
      end

      class ClassifiersInitializer
        CLASSIFIERS_METRICS = {
          agility_total: ->(project) { project.agility.total.metrics_to_hash },
          agility_last_year: ->(project) { project.agility.quarters.last_year_as_hash },
          community_total: ->(project) { project.community.total.metrics_to_hash },
          community_last_year: ->(project) { project.community.quarters.last_year_as_hash }
        }

        def self.load_or_create
          repo = ClassifiersRepo.new(Ossert.rom)
          if repo.actual?
            new.load(repo)
          else
            new(Project.projects_by_reference)
          end
        end

        def initialize(grouped_projects = nil)
          @projects = grouped_projects
        end

        def load(repo)
          @classifiers = {}
          CLASSIFIERS_METRICS.keys.each do |section|
            @classifiers[section] = JSON.parse(repo[section.to_s].reference_values)
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
          repo = ClassifiersRepo.new(Ossert.rom)
          repo.cleanup

          @classifiers.each do |section, reference_values|
            repo.create(
              section: section.to_s,
              reference_values: JSON.generate(reference_values)
            )
          end
        end

        def run
          return @classifiers if @classifiers.present?
          @classifiers = CLASSIFIERS_METRICS.keys.map { |type| [type, {}] }.to_h

          GRADES.each do |grade|
            @projects[grade].each do |project|
              CLASSIFIERS_METRICS.each do |type, metrics|
                @classifiers[type].store(
                  grade,
                  merge_metrics(
                    @classifiers[type][grade].to_h,
                    metrics.call(project)
                  )
                )
              end
            end
          end

          save
          @classifiers
        end
      end
    end
  end
end
