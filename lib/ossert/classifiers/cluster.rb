# frozen_string_literal: true
require 'kmeans-clusterer'

module Ossert
  module Classifiers
    # Class for Cluster classification. Uses K-Means clusterization.
    class Cluster < Base
      THRESHOLDS_PATH = 'cluster/thresholds.yml'
      DISTRIBUTION_PATH = 'cluster/distribution.yml'

      # Prepare and return cluster classifier instance for current
      # configuration state. Uses cluster/thresholds.yml configuration file.
      #
      # @return [Ossert::Classifiers::Cluster] initialized cluster classifer
      def self.current
        @current ||= new(YAML::load_file(Config.path(THRESHOLDS_PATH)))
      end

      # @return [Hash] the configuration of Cluster classifier.
      def self.config
        @config ||= Settings['classifiers_cluster']
      end

      def initialize(thresholds)
        super
        @thresholds = thresholds
      end

      # Run training process using current classifier state.
      #
      # @return [Hash<Symbol, Hash>] collection of classifiers for all combinations
      #   of data sections and periods.
      def train
        run_thresholds
        run_values_to_ranges
        run_reverse

        @classifiers
      end

      # Prepare @classifiers threshold values for each metric and all
      # section vs period combinations.
      #
      # @return not specified.
      def run_thresholds
        SECTIONS.product(PERIODS).each do |section, period|
          GRADES.each_with_index do |grade, idx|
            @thresholds[section][period].each_pair do |metric, values|
              @classifiers["#{section}_#{period}".to_sym][grade][metric] = values[idx]
            end
          end
        end
      end

      # Transform @classifiers threshold metric values to hashes
      # with threshold and range covered.
      #
      # @return not specified.
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

      # Transform @classifiers values of reversed metrics to the correct state.
      #
      # @return not specified.
      def run_reverse
        CLASSIFIERS.each do |classifier_name|
          classifier = @classifiers[classifier_name]
          reversed_metrics.each do |reversed_metric|
            GRADES.first(GRADES.count / 2).each do |grade|
              grade_metrics = classifier[grade]
              next unless grade_metrics[reversed_metric].present?
              reversed_grade_metrics = classifier[REVERSED_GRADES[grade]]

              reversed_grade_metrics[reversed_metric], grade_metrics[reversed_metric] =
                grade_metrics[reversed_metric], reversed_grade_metrics[reversed_metric]
            end
          end
        end
      end

      # Run train process of all Stats for each period on all exisitng projects.
      # Result is saved to cluster/thresholds.yml config file.
      # (see .train_section_metrics_thresholds)
      #
      # @return not specified.
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

      # Run train process given section_klass [Stats::Base descendants] and period.
      # K-Means clusterization algorithm is used to prepare clusters.
      # The centroids of clusters are used as a base for thresholds calculation.
      #
      # @param section_klass [Stats::Base descendant, .metrics] the class which
      #   specifies which metrics to collect and analyze using K-Means.
      # @param period [Symbol] the period specifiation for data extract from a
      #   project
      # @return not specified.
      def self.train_section_metrics_thresholds(section_klass, period)
        raise ArgumentError unless PERIODS.include?(period)

        # TODO: move demodulize and whole logic to Utils somewhere
        section = section_klass.to_s.demodulize.underscore.split('_').first.to_sym
        data = {period => {}}

        Ossert::Project.yield_all do |project|
          next if project.without_github_data?
          project_data = project.data_for(section: section, period: period)
          section_klass.metrics.each do |metric|
            (data[period][metric] ||= []) << [project_data[metric]]
          end
        end

        write_yaml(Config.path(DISTRIBUTION_PATH)) do |distrib_yaml|
          write_yaml do |yaml|
            (yaml[section] ||= {})[period] = {}
            (distrib_yaml[section] ||= {})[period] = {}

            section_klass.metrics.each do |metric|
              # Find the best number of clusters to fit the data
              # ks = 3.upto(5).to_a
              ks = [5] # Using 5 to have valid number of thresholds
              errors, silhouettes = [], []

              runs = ks.map do |k|
                begin
                  kmeans = KMeansClusterer.run k, data[period][metric], runs: 3
                  error, ss = kmeans.error, kmeans.silhouette
                rescue ArgumentError, RuntimeError
                  errors << 0.0
                  silhouettes << 0.0
                  next(kmeans)
                end
                errors << error
                silhouettes << ss
                kmeans
              end

              index_of_max_ss = silhouettes.index silhouettes.max
              bestrun = runs[index_of_max_ss]

              centroids = bestrun.clusters.map do |cluster|
                values = data[period][metric].flatten.values_at(*cluster.points.map(&:id))
                result = (values.inject(&:+) / values.count.to_f).round(2) unless values.count.zero?
                result ||= 0.0

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

      # Write yielded hash to a file name
      #
      # @param name [String] the file path where to write YAML
      # @yieldparam [Hash] the Hash read from the file and which will be
      #   committed to a file on complete
      # @return not specified.
      def self.write_yaml(name = Config.path(THRESHOLDS_PATH))
        require 'yaml'
        yaml = File.exist?(name) ? YAML::load_file(name) : {}
        yield yaml
        File.open(name, 'w') {|f| f.write yaml.to_yaml }
      end
    end
  end
end
