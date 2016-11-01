# frozen_string_literal: true
module Ossert
  module Presenters
    module ProjectV2
      CLASSES = %w(
        ClassE
        ClassD
        ClassC
        ClassB
        ClassA
      ).freeze
      KLASS_2_GRADE = {
        'ClassA' => 'A',
        'ClassB' => 'B',
        'ClassC' => 'C',
        'ClassD' => 'D',
        'ClassE' => 'E'
      }.freeze

      def preview_reference_values_for(metric, section) # maybe automatically find section?
        metric_by_grades = @reference[section][metric.to_s]
        grades = CLASSES.reverse
        sign = reversed_metrics.include?(metric) ? '<' : '>'

        grades.each_with_object({}) do |klass, preview|
          preview[KLASS_2_GRADE[klass]] = "#{sign} #{metric_by_grades[klass][:threshold].to_i}"
        end
      end

      REFERENCES_STUB = {
        'ClassA' => { threshold: '0', range: [] },
        'ClassB' => { threshold: '0', range: [] },
        'ClassC' => { threshold: '0', range: [] },
        'ClassD' => { threshold: '0', range: [] },
        'ClassE' => { threshold: '0', range: [] }
      }.freeze

      # Tooltip data:
      # {
      #   title: '',
      #   description: '',
      #   ranks: [
      #     {"type":"a","year":100,"total":300},
      #     {"type":"b","year":80,"total":240},
      #     {"type":"c","year":60,"total":120},
      #     {"type":"d","year":40,"total":100},
      #     {"type":"e","year":20,"total":80}
      #   ]
      # }
      def tooltip_data(metric)
        classes = CLASSES.reverse
        section = Ossert::Stats.guess_section_by_metric(metric)
        ranks = classes.inject([]) do |preview, klass|
          base = { type: KLASS_2_GRADE[klass].downcase, year: ' N/A ', total: ' N/A ' }
          preview << [:year, :total].each_with_object(base) do |section_type, result|
            next unless (metric_data = metric_tooltip_data(metric, section, section_type, klass)).present?
            result[section_type] = metric_data
          end
        end

        { title: Ossert.t(metric), description: Ossert.descr(metric), ranks: ranks }
      end

      def metric_tooltip_data(metric, section, section_type, klass)
        return if section == :not_found # this should not happen
        reference_section = [section, section_type].join('_')
        return unless (metric_by_grades = @reference[reference_section.to_sym][metric.to_s])

        [
          reversed_metrics.include?(metric) ? '&lt;&nbsp;' : '&gt;&nbsp;',
          decorator.value(metric, metric_by_grades[klass][:threshold])
        ].join(' ')
      end

      def reversed_metrics
        @reversed_metrics ||= Ossert::Classifiers::Growing.config['reversed']
      end

      # Fast preview graph
      # [
      #   {"title":"Jan - Mar 2016","type":"a","values":[10,20]},
      #   {"title":"Apr - Jun 2016","type":"b","values":[20,25]},
      #   {"title":"Jul - Sep 2016","type":"c","values":[25,35]},
      #   {"title":"Oct - Dec 2016","type":"d","values":[35,50]},
      #   {"title":"Next year","type":"e","values":[50,10]}
      # ]
      def fast_preview_graph_data(lookback = 5, check_results = nil)
        graph_data = { popularity: [], maintenance: [], maturity: [] } # replace with config

        check_results.each_with_index do |check_result, index|
          check_result.each do |check, results|
            sum_up_checks(graph_data, check, results, index, lookback - index)
          end
        end
        graph_data.map { |k, v| [k, MultiJson.dump(v)] }.to_h
      end

      def sum_up_checks(graph_data, check, results, index, offset)
        gain = results[:gain]
        graph_data[check] << {
          title: last_quarters_bounds(offset),
          type: results[:mark].downcase,
          values: [gain, gain]
        }

        graph_data[check][index - 1][:values][1] = gain if index.positive?
      end

      def last_quarters_bounds(last_year_offset)
        date = Time.current.utc - ((last_year_offset - 1) * 3).months

        [date.beginning_of_quarter.strftime('%b'),
         date.end_of_quarter.strftime('%b %Y')].join(' - ')
      end
    end
  end
end
