# frozen_string_literal: true

module Ossert
  module Presenters
    module ProjectV2
      # The list of projects class types
      CLASSES = %w[
        ClassE
        ClassD
        ClassC
        ClassB
        ClassA
      ].freeze
      # The map of class to its grade
      KLASS_2_GRADE = {
        'ClassA' => 'A',
        'ClassB' => 'B',
        'ClassC' => 'C',
        'ClassD' => 'D',
        'ClassE' => 'E'
      }.freeze

      # Prepare a preview for reference (per grade) values for given section and metric.
      #
      # @param metric [String] name of metric to find
      # @param classifier [String] name to ask for a data
      # @example
      #   project.decorated.preview_reference_values_for('issues_all_count', 'agility_total')
      #   # =>
      #   # {
      #   #   'A' => '> 92'
      #   #   'B' => '> 68'
      #   #   'C' => '> 19'
      #   #   'D' => '> 10'
      #   #   'E' => '> 2')
      #   # }
      # @return [Hash<String, String>] of thresholds per grade
      def preview_reference_values_for(metric, classifier)
        metric_by_grades = @reference[classifier.to_sym][metric.to_s]
        grades = Ossert::Classifiers::GRADES
        sign = reversed_metrics.include?(metric) ? '<' : '>'

        grades.each_with_object({}) do |klass, preview|
          preview[KLASS_2_GRADE[klass]] = "#{sign} #{metric_by_grades[klass][:threshold].to_i}"
        end
      end

      # Prepare a data for metric thresholds tooltip
      #
      # @param metric [String] for which data to calculate.
      # @example:
      #   project.decorated.tooltip_data('pr_closed_percent')
      #   # =>
      #   # {
      #   #   title: 'Pull Request Closed %',
      #   #   description: 'Pull Request Closed %',
      #   #   ranks: [
      #   #     {"type":"a","year":100,"total":100},
      #   #     {"type":"b","year":80,"total":80},
      #   #     {"type":"c","year":60,"total":60},
      #   #     {"type":"d","year":40,"total":40},
      #   #     {"type":"e","year":20,"total":20}
      #   #   ]
      #   # }
      # @return [Hash] of metric title, descripion and ranks for each grade.
      def tooltip_data(metric)
        classes = CLASSES.reverse
        section = Ossert::Stats.guess_section_by_metric(metric)
        ranks = classes.inject([]) do |preview, klass|
          base = { type: KLASS_2_GRADE[klass].downcase, quarter: ' N/A ', last_year: ' N/A ', total: ' N/A ' }
          rank = %i[quarter last_year total].each_with_object(base) do |period, result|
            next unless (metric_data = metric_tooltip_data(metric, section, period, klass)).present?

            result[period] = metric_data
          end
          rank[:year] = rank.delete(:last_year)
          preview << rank
        end

        { title: Ossert.t(metric), description: Ossert.descr(metric), ranks: ranks }
      end

      # Prepare info string about grade threshold for metric in a section and
      # a period
      #
      # @param metric [String] name to lookup
      # @param section [String] metric section for classifier lookup
      # @param period [String] metric period for classifier lookup
      # @param klass [String of Ossert::Classifier::GRADES] to prepare info for
      # @example
      #   project.decorated.metric_tooltip_data('pr_closed_percent', 'agility', 'total', 'ClassA')
      #   # => "&gt;&nbsp;90"
      # @return [String] information about threshold for a tooltip
      def metric_tooltip_data(metric, section, period, klass)
        return if section == :not_found # WTF?!? this should not happen

        classifier_name = "#{section}_#{period}".to_sym
        return unless (metric_by_grades = @reference[classifier_name][metric.to_s])

        [
          reversed_metrics.include?(metric) ? '&lt;&nbsp;' : '&gt;&nbsp;',
          decorator.value(metric, metric_by_grades[klass][:threshold])
        ].join(' ')
      end

      # @return [Array<String>] of reversed metrics
      def reversed_metrics
        @reversed_metrics ||= Ossert::Classifiers::Growing.config['reversed']
      end

      # Prepare data for fast preview graph for a project
      #
      # @param check_results [Array<Hash>] list of grades and scores back in
      #   history for popularity, maintenance and maturity.
      # @param lookback [Numeric] how deep to go back in history for calc.
      # @example
      #   project.decorated.fast_preview_graph_data
      #   # =>
      #   # {
      #   #   popularity: "
      #   #     [
      #   #       {"title":"Jan - Mar 2016","type":"a","values":[10,20]},
      #   #       {"title":"Apr - Jun 2016","type":"b","values":[20,25]},
      #   #       {"title":"Jul - Sep 2016","type":"c","values":[25,35]},
      #   #       {"title":"Oct - Dec 2016","type":"d","values":[35,50]},
      #   #       {"title":"Next year","type":"e","values":[50,10]}
      #   #     ]
      #   #   ",
      #   #   ...
      #   # }
      # @return [Hash<Symbol, JSON String>]
      def fast_preview_graph_data(check_results, lookback = 5)
        graph_data = { popularity: [], maintenance: [], maturity: [] } # replace with config

        check_results.to_a.each_with_index do |check_result, index|
          check_result.each do |check, results|
            sum_up_checks(graph_data, check, results, index, lookback - index)
          end
        end
        graph_data.map { |k, v| [k, MultiJson.dump(v)] }.to_h
      end

      def sum_up_checks(graph_data, check, results, index, offset)
        score = results[:score]
        graph_data[check] << {
          title: last_quarters_bounds_name(offset),
          type: results[:mark].downcase,
          values: [score, score]
        }

        graph_data[check][index - 1][:values][1] = score if index.positive?
      end

      # Prepare the name of quarter bounds for given offset for current time.
      #
      # @param last_year_offset [Numeric] for which quarter is located.
      # @example
      #   project.decorated.last_quarters_bounds_name(1) # => "Oct - Dec 2016"
      # @return [String]
      def last_quarters_bounds_name(last_year_offset)
        date = Time.current.utc - ((last_year_offset - 1) * 3).months

        [date.beginning_of_quarter.strftime('%b'),
         date.end_of_quarter.strftime('%b %Y')].join(' - ')
      end
    end
  end
end
