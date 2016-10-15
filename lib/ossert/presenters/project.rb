module Ossert
  module Presenters
    class Project
      CLASSES = %w(ClassE ClassD ClassC ClassB ClassA)
      attr_reader :project

      def initialize(project)
        @project = project
        @reference = Ossert::Classifiers::Growing.current.reference_values_per_class
      end

      def with_reference(text, value, metric, type)
        return (text.to_i > 0 ? "+#{text}" : text).to_s if type =~ /delta/

        metric_by_ref = @reference[type][metric]
        reference = CLASSES.inject('NaN') do |acc, ref|
          metric_by_ref[ref][:range].cover?(value.to_f) ? ref : acc
        end
        "#{text} (#{reference.gsub(/Class/, '')})"
      rescue => e
        puts "NO DATA FOR METRIC: '#{metric}'"
        raise e
      end

      def percent(value)
        "#{value}%"
      end

      def date(value)
        Time.at(value).strftime('%d-%m-%Y')
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
          "~#{value} day"
        when 2..30
          "~#{value} days"
        when 31..61
          "~#{value / 31} month"
        else
          "~#{value / 31} months"
        end
      end

      def downloads(value)
        value.to_s.gsub(/\d(?=(...)+$)/, '\0,')
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
          metric_name = metric.to_s.gsub(/(_percent|_int|_count)/, '')
          next if metric =~ /active/
          res[metric_name] = decorate_metric metric, value, :agility_total
        end
      end

      def agility_quarter(quarter)
        quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter
        prev_quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter - 1.day
        prev = @project.agility.quarters[prev_quarter].metrics_to_hash.each_with_object({}) do |(metric, value), res|
          metric_name = metric.to_s.gsub(/(_percent|_int|_count)/, '')
          res[metric_name] = value.to_i
        end
        @project.agility.quarters[quarter].metrics_to_hash.each_with_object({}) do |(metric, value), res|
          metric_name = metric.to_s.gsub(/(_percent|_int|_count)/, '')
          res[metric_name] = decorate_metric(metric, value, :agility_quarter) + ' <> ' +
                            decorate_metric(metric, value.to_i - prev[metric_name], :delta)
        end
      end

      def agility_quarter_values(quarter)
        quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter
        @project.agility.quarters[quarter].metrics_to_hash.each_with_object({}) do |(metric, value), res|
          metric_name = metric.to_s.gsub(/(_percent|_int|_count)/, '')
          res[metric_name] = value
        end
      end

      def community_total
        @project.community.total.metrics_to_hash.each_with_object({}) do |(metric, value), res|
          metric_name = metric.to_s.gsub(/(_percent|_int|_count)/, '')
          res[metric_name] = decorate_metric metric, value, :community_total
        end
      end

      def community_quarter(quarter)
        quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter
        prev_quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter - 1.day
        prev = @project.community.quarters[prev_quarter].metrics_to_hash.each_with_object({}) do |(metric, value), res|
          metric_name = metric.to_s.gsub(/(_percent|_int|_count)/, '')
          res[metric_name] = value.to_i
        end
        @project.community.quarters[quarter].metrics_to_hash.each_with_object({}) do |(metric, value), res|
          metric_name = metric.to_s.gsub(/(_percent|_int|_count)/, '')
          res[metric_name] = decorate_metric(metric, value, :community_quarter) + ' <> ' +
                            decorate_metric(metric, value.to_i - prev[metric_name], :delta)
        end
      end

      def community_quarter_values(quarter)
        quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter
        @project.community.quarters[quarter].metrics_to_hash.each_with_object({}) do |(metric, value), res|
          metric_name = metric.to_s.gsub(/(_percent|_int|_count)/, '')
          res[metric_name] = value
        end
      end

      def community_last_year
        quarters_end_date = Time.current
        quarters_start_date = 1.year.ago
        data = Hash.new { |h,k| h[k] = 0.0 }

        quarters_end_date.to_i.step(quarters_start_date.to_i, -90.days.to_i) do |quarter|
          quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter
          @project.community.quarters[quarter].metrics_to_hash.each_with_object(data) do |(metric, value), res|
            next if metric =~ /total_downloads/
            res[metric] += value.to_f
          end
        end

        data.each_with_object({}) do |(metric, value), h|
          metric_name = metric.to_s.gsub(/(_percent|_int|_count)/, '')
          value = metric =~ /divergence/ ? (value / 5.0.to_d) : value
          h[metric_name] = decorate_metric(metric, value.ceil, :community_year)
          h
        end
      end

      def agility_last_year
        quarters_end_date = Time.current
        quarters_start_date = 1.year.ago
        data = Hash.new { |h,k| h[k] = 0 }

        quarters_start_date.to_i.step(quarters_end_date.to_i, 91.days.to_i) do |quarter|
          quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter
          @project.agility.quarters[quarter].metrics_to_hash.each_with_object(data) do |(metric, value), res|
            case metric
            when /processed/
              res[metric] = Array.new unless res[metric].is_a? Array
              res[metric] += @project.agility.quarters[quarter].send(metric.to_s.gsub(/in_avg/, 'in_days')).to_a
            when /closed/
              res[metric] = Set.new unless res[metric].is_a? Set
              res[metric] += @project.agility.quarters[quarter].send(metric.to_s.gsub(/_percent/, ''))
            when /active/
              next
            when /actual/
              next
            when /all/
              res[metric] = Set.new unless res[metric].is_a? Set
              res[metric] += @project.agility.quarters[quarter].send(metric.to_s.gsub(/_count/, ''))
            else
              res[metric] += value.to_f
            end
          end
        end

        result = {
          issues_legacy: @project.agility.quarters[quarters_start_date].issues_actual_count,
          pr_legacy: @project.agility.quarters[quarters_start_date].pr_actual_count
        }

        data.inject(result) do |h, (metric, value)|
          metric_name = metric.to_s.gsub(/(_percent|_int|_count)/, '')
          case metric
          when /processed/
            values = value.sort
            value = if values.count.odd?
                      values[values.count/2]
                    elsif values.count.zero?
                      0
                    else
                      (values[values.count/2 - 1] + values[values.count/2]) / 2.0
                    end
          when /percent/
            count = data["#{metric.to_s.split('_').first}_all_count".to_sym].count
            value = count.zero? ? 0 : (value.count * 100) / count.to_d
          when /all/
            value = value.count
          end
          h[metric_name] = decorate_metric(metric, value.to_i, :agility_year)
          h
        end
      end
    end
  end
end
