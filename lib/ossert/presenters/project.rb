require 'ossert/presenters/project_v2'

module Ossert
  module Presenters
    # FIXME: Temporary version. Will be changed when new design uppear
    class Project
      include Ossert::Presenters::ProjectV2

      CLASSES = %w(ClassE ClassD ClassC ClassB ClassA)
      attr_reader :project

      def initialize(project)
        @project = project
        @reference = Ossert::Classifiers::Growing.current.reference_values_per_grade
      end

      def preview_reference_values_for(metric, section) # maybe automatically find section?
        metric_by_grades = @reference[section][metric.to_s]
        grades = CLASSES.reverse
        sign = metric_by_grades[grades.first][:range].include?(-Float::INFINITY) ? '<' : '>'

        grades.each_with_object({}) do |grade, preview|
          preview[grade.sub(/Class/, '')] = "#{sign} #{metric_by_grades[grade][:threshold].to_i}"
        end
      end

      def with_reference(text, value, metric, type)
        return (text.to_i > 0 ? "+#{text}" : text).to_s if type =~ /delta/

        metric_by_ref = @reference[type][metric.to_s]
        reference = CLASSES.inject('NaN') do |acc, ref|
          metric_by_ref[ref][:range].cover?(value.to_f) ? ref : acc
        end

        mark = reference.gsub(/Class/, '')
        {
          text: "#{text}&nbsp;#{mark}",
          mark: mark.downcase
        }
      rescue => e
        puts "NO DATA FOR METRIC: '#{metric}'"
        raise e
      end

      def percent(value)
        "#{value}%"
      end

      def date(value)
        Time.at(value).strftime('%d/%m/%y')
      end

      def years(value)
        if (years = value.to_i / 365) > 0
          "#{years}+ years"
        else
          "Less than a year"
        end
      end

      def days(value)
        case value
        when 0
          "not enough data"
        when 1
          "~#{value.ceil} day"
        when 2..30
          "~#{value.ceil} days"
        when 31..61
          "~#{(value / 31).ceil} month"
        else
          "~#{(value / 31).ceil} months"
        end
      end

      def downloads(value)
        value.to_s.gsub(/\d(?=(...)+$)/, '\0,')
      end

      def decorate_value(metric, value)
        case metric.to_s
        when /(percent|divergence)/
          percent(value)
        when /(date|changed)/
          date(value)
        when /processed_in/
          days(value)
        when /period/
          years(value)
        when /count/
          value.to_i
        when /downloads/
          downloads(value)
        else
          value
        end
      end

      def decorate_metric(metric, value, type)
        case metric.to_s
        when /(percent|divergence)/
          with_reference(
            percent(value),
            value,
            metric,
            type
          )
        when /(date|changed)/
          with_reference(
            date(value),
            value,
            metric,
            type
          )
        when /processed_in/
          with_reference(
            days(value),
            value,
            metric,
            type
          )
        when /period/
          with_reference(
            years(value),
            value,
            metric,
            type
          )
        when /count/
          with_reference(
            value.to_i,
            value,
            metric,
            type
          )
        when /downloads/
          with_reference(
            downloads(value),
            value,
            metric,
            type
          )
        when /legacy/
          with_reference(
            value,
            value,
            metric.to_s.sub(/legacy/,'actual') + "_count",
            type
          )
        else
          with_reference(
            value,
            value,
            metric,
            type
          )
        end
      end

      def agility_total
        @project.agility.total.metrics_to_hash.each_with_object({}) do |(metric, value), res|
          next if metric =~ /active/
          res[metric] = decorate_metric metric, value, :agility_total
        end
      end

      def community_total
        @project.community.total.metrics_to_hash.each_with_object({}) do |(metric, value), res|
          res[metric] = decorate_metric metric, value, :community_total
        end
      end

      def agility_quarter(quarter)
        quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter
        prev_quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter - 1.day

        prev = @project.agility.quarters[prev_quarter].metrics_to_hash.each_with_object({}) do |(metric, value), res|
          res[metric] = value.to_i
        end
        @project.agility.quarters[quarter].metrics_to_hash.each_with_object({}) do |(metric, value), result|
          result[Ossert.t(metric)] = decorate_metric(metric, value, :agility_quarter) + ' <> ' +
                                  decorate_metric(metric, value.to_i - prev[metric], :delta)
        end
      end

      def community_quarter(quarter)
        quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter
        prev_quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter - 1.day

        prev = @project.community.quarters[prev_quarter].metrics_to_hash.each_with_object({}) do |(metric, value), res|
          res[metric] = value.to_i
        end

        @project.community.quarters[quarter].metrics_to_hash.each_with_object({}) do |(metric, value), result|
          result[Ossert.t(metric)] = decorate_metric(metric, value, :community_quarter) + ' <> ' +
                                  decorate_metric(metric, value.to_i - prev[metric], :delta)
        end
      end

      def agility_quarter_values(quarter)
        quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter

        @project.agility.quarters[quarter].metrics_to_hash.each_with_object({}) do |(metric, value), result|
          result[metric] = value
        end
      end

      def community_quarter_values(quarter)
        quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter
        @project.community.quarters[quarter].metrics_to_hash.each_with_object({}) do |(metric, value), result|
          result[metric] = value
        end
      end

      def community_last_year
        @project.community.quarters.last_year_as_hash.each_with_object({}) do |(metric, value), result|
          result[metric] = decorate_metric(metric, value.to_i, :community_year)
        end
      end

      def agility_last_year
        @project.agility.quarters.last_year_as_hash.each_with_object({}) do |(metric, value), result|
          result[metric] = decorate_metric(metric, value.to_i, :agility_year)
        end
      end
    end
  end
end
