# frozen_string_literal: true
require 'kmeans-clusterer'

module Ossert
  module Classifiers
    class Cluster
      THRESHOLDS_PATH = File.join(Ossert::Config::CONFIG_ROOT, 'cluster/thresholds.yml')

      def self.current
        @current ||= new(YAML::load_file(THRESHOLDS_PATH))
      end

      def self.config
        @config ||= Settings['classifiers_cluster']
      end

      def self.reversed_metrics
        @reversed_metrics ||= config['reversed']
      end

      def initialize(thresholds)
        @thresholds = thresholds
        @classifiers = {}
      end

      def ready?
        [@classifiers[:agility_total],
         @classifiers[:community_total],
         @classifiers[:agility_last_year],
         @classifiers[:community_last_year]].all? { |c| c.present? }
      end

      def process_using(action, project, last_year_offset = 1)
        Check.send(action,
                   self.class.config,
                   project,
                   CLASSIFIERS.map { |name| [name, @classifiers[name]] }.to_h,
                   last_year_offset)
      end

      def grade(*args)
        process_using(*args.unshift(:grade))
      end

      def check(*args)
        process_using(*args.unshift(:check))
      end

      def reference_values_per_grade
        SECTION.product(PERIODS).map do |section, period|
          ["#{section}_#{period}".to_sym, classifier_to_metrics_per_grade(section, period)]
        end.to_h
      end

      def classifier_to_metrics_per_grade(section, period)
        @classifiers["#{section}_#{period}"].each_with_object({}) do |(grade, metrics), res|
          metrics.each do |metric, value|
            (res[metric] ||= {})[grade] = value
          end
        end
      end

      def train
        run_thresholds
        run_values_to_ranges
        run_reverse

        @classifiers
      end

      class ThresholdToRange
        def self.range_for(metric, value, grade)
          new(metric, value, grade).range
        end

        def initialize(metric, value, grade)
          @metric = metric
          @value = value
          @grade = grade
        end

        def range
          if reversed_metrics.include?(@metric)
            Reversed.new(@value, @grade).range
          else
            Base.new(@value, @grade).range
          end
        end

        def reversed_metrics
          @reversed_metrics ||= Ossert::Classifiers::Cluster.config['reversed']
        end

        class Base
          def initialize(value, grade)
            @value = value
            @full_range = (grade == last_grade)
          end

          def range
            return full_range if full_range?
            start_value...end_value
          end

          private

          def full_range?
            @full_range
          end

          def last_grade
            GRADES.last
          end

          def full_range
            -Float::INFINITY...Float::INFINITY
          end

          def start_value
            @value
          end

          def end_value
            Float::INFINITY
          end
        end

        class Reversed < Base
          def last_grade
            GRADES.first
          end

          def start_value
            -Float::INFINITY
          end

          def end_value
            @value
          end
        end
      end

      def run_thresholds
        SECTIONS.each do |section|
          PERIODS.each do |period|
            GRADES.each_with_index do |grade, idx|
              @thresholds[section][period].each_pair do |metric, values|
                ((@classifiers["#{section}_#{period}".to_sym] ||= {})[grade] ||= {})[metric] = values[idx]
              end
            end
          end
        end
      end

      def run_values_to_ranges
        CLASSIFIERS.each do |classifier_name|
          classifier = @classifiers[classifier_name]
          GRADES.each do |grade|
            classifier[grade].each_pair do |metric, value|
              classifier[grade][metric] = {
                threshold: value,
                range: ThresholdToRange.range_for(metric, value, grade)
              }
            end
          end
        end
      end

      def run_reverse
        CLASSIFIERS.each do |classifier_name|
          classifier = @classifiers[classifier_name]
          self.class.reversed_metrics.each do |reversed_metric|
            GRADES.first(GRADES.count / 2).each do |grade|
              grade_metrics = classifier[grade]
              next unless grade_metrics[reversed_metric].present?
              reversed_grade_metrics = classifier[REVERSED_GRADE[grade]]

              reversed_grade_metrics[reversed_metric], grade_metrics[reversed_metric] =
                grade_metrics[reversed_metric], reversed_grade_metrics[reversed_metric]
            end
          end
        end
      end

      def self.train_all_sections_thresholds
        {
          Ossert::Stats::AgilityQuarter => [:quarter, :last_year],
          Ossert::Stats::AgilityTotal => [:total],
          Ossert::Stats::CommunityQuarter => [:quarter, :last_year],
          Ossert::Stats::CommunityTotal => [:total]
        }.each_pair do |section_klass, periods|
          periods.each do |period|
            train_section_metrics_thresholds(section_klass, period)
          end
        end
      end

      def self.train_section_metrics_thresholds(section_klass, period)
        raise ArgumentError unless period.to_sym.in? %i(total last_year quarter)

        section = section_klass.to_s.demodulize.underscore.split('_').first.to_sym
        data = {period => {}}

        Ossert::Project.yield_all do |project|
          next if project.without_github_data?
          project_data = project.data_for(section: section, period: period)
          section_klass.metrics.each do |metric|
            (data[period][metric] ||= []) << [project_data[metric]]
          end
        end

        write_yaml do |yaml|
          (yaml[section] ||= {})[period] = {}

          section_klass.metrics.each do |metric|
            kmeans = KMeansClusterer.run 5, data[period][metric], scale_data: true
            centroids = kmeans.clusters.map { |c| c.centroid.to_a.first.round(2) }.sort.reverse
            thresholds =  if reversed_metrics.include?(metric)
                            [
                              centroids[0],
                              centroids[0..2].sum / 3.0,
                              centroids[1..3].sum / 3.0,
                              centroids[2..4].sum / 3.0,
                              centroids[3..4].sum / 2.0
                            ]
                          else
                            [
                              centroids[0..2].sum / 3.0,
                              centroids[1..3].sum / 3.0,
                              centroids[2..4].sum / 3.0,
                              centroids[3..4].sum / 2.0,
                              centroids[4],
                            ]
                          end

            yaml[section][period][metric] = centroids
          end
        end
      end

      def self.write_yaml
        require 'yaml'
        yaml = YAML::load_file('./config/cluster/thresholds.yml')
        yield yaml
        File.open('./config/cluster/thresholds.yml', 'w') {|f| f.write yaml.to_yaml }
      end
    end
  end
end
