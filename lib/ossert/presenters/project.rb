# frozen_string_literal: true
require 'ossert/presenters/project_v2'

module Ossert
  module Presenters
    class Project
      include Ossert::Presenters::ProjectV2

      attr_reader :project, :decorator

      def initialize(project)
        @project = project
        @reference = Ossert::Classifiers::Growing.current.reference_values_per_grade
        @decorator = Decorator.new(@reference)
      end

      # Prepare a preview structure of all data for a project.
      #
      # @param project [Ossert::Project] to take data from
      # @return [Hash] of preview data
      def self.preview_for(project)
        locals = {
          project: project,
          metric_lookup: {},
          popularity_metrics: Stats.popularity_metrics,
          maintenance_metrics: Stats.maintenance_metrics,
          maturity_metrics: Stats.maturity_metrics
        }
        Ossert::Presenters::Project.with_presenter(project) do |project_decorated|
          (locals[:popularity_metrics] + locals[:maintenance_metrics] + locals[:maturity_metrics]).each do |metric|
            locals[:metric_lookup][metric] = project_decorated.metric_preview(metric)
          end
          locals[:fast_preview_graph] = project_decorated.fast_preview_graph
          locals[:analysis] = project_decorated.grade
        end
        locals
      end

      def self.with_presenter(project)
        presenter = new(project)
        presenter.prepare!
        yield(presenter)
        presenter.cleanup_references!
      end

      class Decorator
        def initialize(reference)
          @reference = reference
        end

        # value, Float !
        def with_reference(text, value, metric, type)
          return (text.to_i.positive? ? "+#{text}" : text).to_s if type == :delta

          metric_by_ref = @reference[type][metric.to_s]
          reference = Project::CLASSES.inject('NaN') do |acc, ref|
            metric_by_ref[ref][:range].cover?(value) ? ref : acc
          end

          { text: "#{text}&nbsp;#{Project::KLASS_2_GRADE[reference]}",
            value: value,
            mark: Project::KLASS_2_GRADE[reference].downcase }
        rescue => e
          puts "NO DATA FOR METRIC: '#{metric}'"
          raise e
        end

        TOO_LONG_AGO = 20.years.ago
        METRICS_DECORATIONS = {
          /(percent|divergence)/ => ->(value) { "#{value.ceil}%" },
          /(date|changed)/ => (lambda do |value|
            date = Time.at(value)
            return 'N/A' if date < TOO_LONG_AGO
            date.strftime('%d/%m/%y')
          end),
          /processed_in/ => (lambda do |value|
            return 'N/A' if value >= Ossert::Stats::PER_YEAR_TOO_LONG || value.zero?
            case value
            when 1
              "~#{value.ceil} day"
            when 2..30
              "~#{value.ceil} days"
            when 31..61
              "~#{(value / 31).to_i} month"
            else
              "~#{(value / 31).to_i} months"
            end
          end),
          /period/ => (lambda do |value|
            if (years = value.to_i / 1.year.to_i).positive?
              "#{years}+ years"
            else
              'Less than a year'
            end
          end),
          /downloads/ => ->(value) { value.ceil.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse }
        }.freeze

        def value(metric, value)
          value = value.to_f
          METRICS_DECORATIONS.each { |check, decorator| return decorator.call(value) if metric =~ check }
          value.to_i
        end

        def metric(metric, value, type)
          with_reference(value(metric, value), value.to_f, metric, type)
        end

        def quarter_with_diff(project, time, section)
          section_type = "#{section}_quarter".to_sym
          quarter_data = project.send(section).quarters[quarter_start(time)].metrics_to_hash
          diff = quarter_values(project.send(section).quarters[quarter_start(time) - 1.day].metrics_to_hash)

          quarter_data.each_with_object({}) do |(metric, value), result|
            decorated_metric = metric(metric, value, section_type)
            result[Ossert.t(metric)] = <<-TEXT
  #{decorated_metric[:text]} <> #{metric(metric, value.to_i - diff[metric], :delta)}
            TEXT
          end
        end

        def metrics(metrics_data, section_type)
          metrics_data.each_with_object({}) do |(metric, value), result|
            result[metric] = metric(metric, value.to_i, section_type)
          end
        end

        def quarter_values(quarter_data)
          quarter_data.each_with_object({}) do |(metric, value), res|
            res[metric] = value.to_i
          end
        end

        private

        def quarter_start(time)
          Time.at(time).to_date.to_time(:utc).beginning_of_quarter
        end
      end

      def agility_quarter(time)
        decorator.quarter_with_diff(@project, time, :agility)
      end

      def community_quarter(time)
        decorator.quarter_with_diff(@project, time, :community)
      end

      def agility_quarter_values(time)
        decorator.quarter_values @project.agility.quarters[time].metrics_to_hash
      end

      def community_quarter_values(time)
        decorator.quarter_values @project.community.quarters[time].metrics_to_hash
      end

      def agility_total
        @agility_total ||= decorator.metrics @project.agility.total.metrics_to_hash, :agility_total
      end

      def community_total
        @community_total ||= decorator.metrics @project.community.total.metrics_to_hash, :community_total
      end

      def community_last_year
        @community_last_year ||= decorator.metrics @project.community.quarters.last_year_as_hash, :community_last_year
      end

      def agility_last_year
        @agility_last_year ||= decorator.metrics @project.agility.quarters.last_year_as_hash, :agility_last_year
      end

      def metric_preview(metric)
        preview = {}
        return(preview) if (section = Ossert::Stats.guess_section_by_metric(metric)) == :not_found

        preview[:tooltip] = MultiJson.dump(tooltip_data(metric))
        preview[:translation] = Ossert.t(metric)

        preview.merge!(section_metric_data(metric, section, :last_year))
        preview.merge!(section_metric_data(metric, section, :total))
        preview
      end

      def metric_history(metric)
        return [] if (section = Ossert::Stats.guess_section_by_metric(metric)) == :not_found
        return [] unless Kernel.const_get("Ossert::Stats::#{section.capitalize}Quarter").metrics.include? metric

        history = []
        @project.send(section).quarters.reverse_each_sorted do |quarter, data|
          decorated_metric = decorator.metric(metric, data.send(metric), "#{section}_quarter".to_sym)
          history << {
            value: decorated_metric[:value],
            title: decorated_metric[:text],
            grade: decorated_metric[:mark]
          }
        end
        history
      end

      def section_metric_data(metric, section, section_type)
        data = public_send("#{section}_#{section_type}")[metric]
        {
          "#{section_type}_mark".to_sym => data.try(:[], :mark),
          "#{section_type}_text".to_sym => data.try(:[], :text) || 'N/A',
          "#{section_type}_val".to_sym => data.try(:[], :value) || 'N/A'
        }
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

        @grade = check_results.last(2).first.map { |k, v| [k, v[:mark].downcase] }.to_h
        @fast_preview_graph = fast_preview_graph_data(check_results, lookback)
      end
      attr_reader :grade, :fast_preview_graph

      def cleanup_references!
        @reference = nil
        @project = nil
        @fast_preview_graph_data = nil
        @grade = nil
        @decorator = nil
      end
    end
  end
end
