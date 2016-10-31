# frozen_string_literal: true
require 'ossert/presenters/project_v2'

module Ossert
  module Presenters
    class Project
      include Ossert::Presenters::ProjectV2

      attr_reader :project

      def initialize(project)
        @project = project
        @reference = Ossert::Classifiers::Growing.current.reference_values_per_grade
      end

      def self.with_presenter(project)
        presenter = new(project)
        presenter.prepare!
        yield(presenter)
        presenter.cleanup_references!
        presenter = nil
      end

      # value, Float !
      def with_reference(text, value, metric, type)
        return (text.to_i.positive? ? "+#{text}" : text).to_s if type == :delta
        metric_by_ref = @reference[type][metric.to_s]
        reference = CLASSES.inject('NaN') do |acc, ref|
          metric_by_ref[ref][:range].cover?(value) ? ref : acc
        end

        { text: "#{text}&nbsp;#{KLASS_2_GRADE[reference]}", mark: KLASS_2_GRADE[reference].downcase }
      rescue => e
        puts "NO DATA FOR METRIC: '#{metric}'"
        raise e
      end

      METRICS_DECORATIONS = {
        /(percent|divergence)/ => ->(value) { "#{value.ceil}%" },
        /(date|changed)/ => ->(value) { Time.at(value).strftime('%d/%m/%y') },
        /processed_in/ => (lambda do |value|
          case value
          when 0
            'not enough data'
          when 1
            "~#{value.ceil} day"
          when 2..30
            "~#{value.ceil} days"
          when 31..61
            "~#{(value / 31).ceil} month"
          else
            "~#{(value / 31).ceil} months"
          end
        end),
        /period/ => (lambda do |value|
          if (years = value.to_i / 365).positive?
            "#{years}+ years"
          else
            'Less than a year'
          end
        end),
        /count/ => ->(value) { value.to_i },
        /downloads/ => ->(value) { value.ceil.to_s.gsub(/\d(?=(...)+$)/, '\0,') }
      }.freeze

      def decorate_value(metric, value)
        value = value.to_f
        METRICS_DECORATIONS.each { |check, decorator| return decorator.call(value) if metric =~ check }
        value.to_i
      end

      def decorate_metric(metric, value, type)
        with_reference(decorate_value(metric, value), value.to_f, metric, type)
      end

      def agility_quarter(time)
        decorate_quarter_with_diff(time, :agility)
      end

      def community_quarter(time)
        decorate_quarter_with_diff(time, :community)
      end

      def agility_quarter_values(time)
        quarter_values @project.agility.quarters[time].metrics_to_hash
      end

      def community_quarter_values(time)
        quarter_values @project.community.quarters[time].metrics_to_hash
      end

      def agility_total
        @agility_total ||= decorate_metrics @project.agility.total.metrics_to_hash, :agility_total
      end

      def community_total
        @community_total ||= decorate_metrics @project.community.total.metrics_to_hash, :community_total
      end

      def community_last_year
        @community_last_year ||= decorate_metrics @project.community.quarters.last_year_as_hash, :community_year
      end

      def agility_last_year
        @agility_last_year ||= decorate_metrics @project.agility.quarters.last_year_as_hash, :agility_year
      end

      def prepare!
        agility_total
        agility_last_year
        community_total
        community_last_year

        lookback = 5
        check_results = (lookback - 1).downto(0).map do |last_year_offset|
          Ossert::Classifiers::Growing.current.check(@project, last_year_offset)
        end
        @fast_preview_graph_data = fast_preview_graph_data(lookback, check_results)
      end

      def cleanup_references!
        @reference = nil
        @project = nil
      end

      private

      def quarter_start(time)
        Time.at(time).to_date.to_time(:utc).beginning_of_quarter
      end

      def quarter_values(quarter_data)
        quarter_data.each_with_object({}) do |(metric, value), res|
          res[metric] = value.to_i
        end
      end

      def decorate_metrics(metrics_data, section_type)
        metrics_data.each_with_object({}) do |(metric, value), result|
          result[metric] = decorate_metric(metric, value.to_i, section_type)
        end
      end

      def decorate_quarter_with_diff(time, section)
        section_type = "#{section}_quarter".to_sym
        quarter_data = @project.send(section).quarters[quarter_start(time)].metrics_to_hash
        diff = quarter_values(@project.send(section).quarters[quarter_start(time) - 1.day].metrics_to_hash)

        quarter_data.each_with_object({}) do |(metric, value), result|
          decorated_metric = decorate_metric(metric, value, section_type)
          result[Ossert.t(metric)] = <<-TEXT
#{decorated_metric[:text]} <> #{decorate_metric(metric, value.to_i - diff[metric], :delta)}
          TEXT
        end
      end
    end
  end
end
