# frozen_string_literal: true
require 'kmeans-clusterer'

module Ossert
  module Classifiers
    class Cluster < Base
      THRESHOLDS_PATH = File.join(Ossert::Config::CONFIG_ROOT, 'cluster/thresholds.yml')
      DISTRIBUTION_PATH = File.join(Ossert::Config::CONFIG_ROOT, 'cluster/distribution.yml')

      def self.current
        @current ||= new(YAML::load_file(THRESHOLDS_PATH))
      end

      def self.config
        @config ||= Settings['classifiers_cluster']
      end

      def initialize(thresholds)
        super
        @thresholds = thresholds
      end

      def train
        run_thresholds
        run_values_to_ranges
        run_reverse

        @classifiers
      end

      def run_thresholds
        SECTIONS.product(PERIODS).each do |section, period|
          GRADES.each_with_index do |grade, idx|
            @thresholds[section][period].each_pair do |metric, values|
              @classifiers["#{section}_#{period}".to_sym][grade][metric] = values[idx]
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
                range: ThresholdToRange.new(
                  metric, value, grade, reversed: ->(m) { reversed_metrics.include?(m) }
                ).range
              }
            end
          end
        end
      end

      def run_reverse
        CLASSIFIERS.each do |classifier_name|
          classifier = @classifiers[classifier_name]
          reversed_metrics.each do |reversed_metric|
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

        write_yaml(DISTRIBUTION_PATH) do |distrib_yaml|
          write_yaml do |yaml|
            (yaml[section] ||= {})[period] = {}
            (distrib_yaml[section] ||= {})[period] = {}

            section_klass.metrics.each do |metric|
              # Find the best number of clusters to fit the data
              ks = 3.upto(10).to_a
              errors, silhouettes = [], []

              runs = ks.map do |k|
                kmeans = KMeansClusterer.run k, data[period][metric], runs: 3
                error, ss = kmeans.error, kmeans.silhouette
                errors << error
                silhouettes << ss
                puts "#{k}\t#{ss.round(2)}\t\t#{error.round(1)}"
                kmeans
              end

              index_of_max_ss = silhouettes.index silhouettes.max
              bestrun = runs[index_of_max_ss]

              centroids = bestrun.clusters.map do |cluster|
                values = data[period][metric].flatten.values_at(*cluster.points.map(&:id))
                result = (values.inject(&:+) / values.count.to_f).round(2)

                (distrib_yaml[section][period][metric] ||= {})[result] = values.count

                result
              end.sort.reverse

              distrib_yaml[section][period][metric] = distrib_yaml[section][period][metric].sort.reverse.to_h


              # Hardcode way to make centroids more accessible for arbitrary project
              #
              # centroids = kmeans.clusters.map { |c| c.centroid.to_a.first.round(2) }.sort.reverse
              # thresholds =  if reversed_metrics.include?(metric)
              #                 [
              #                   centroids[0],
              #                   (centroids[0..2].sum / 3.0).round(2),
              #                   (centroids[1..3].sum / 3.0).round(2),
              #                   (centroids[2..4].sum / 3.0).round(2),
              #                   (centroids[3..4].sum / 2.0).round(2)
              #                 ]
              #               else
              #                 [
              #                   (centroids[0..2].sum / 3.0).round(2),
              #                   (centroids[1..3].sum / 3.0).round(2),
              #                   (centroids[2..4].sum / 3.0).round(2),
              #                   (centroids[3..4].sum / 2.0).round(2),
              #                   centroids[4],
              #                 ]
              #               end

              yaml[section][period][metric] = centroids
            end
          end
        end
      end

      def self.write_yaml(name = THRESHOLDS_PATH)
        require 'yaml'
        yaml = YAML::load_file(name)
        yield yaml
        File.open(name, 'w') {|f| f.write yaml.to_yaml }
      end
    end
  end
end
