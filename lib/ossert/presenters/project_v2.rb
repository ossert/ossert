module Ossert
  module Presenters
    # FIXME: Temporary version. Will be changed when new design uppear
    module ProjectV2
      CLASSES = %w(ClassE ClassD ClassC ClassB ClassA)

      def preview_reference_values_for(metric, section) # maybe automatically find section?
        metric_by_grades = @reference[section][metric.to_s]
        grades = CLASSES.reverse
        sign = metric_by_grades[grades.first][:range].include?(-Float::INFINITY) ? '<' : '>'

        grades.each_with_object({}) do |grade, preview|
          preview[grade.sub(/Class/, '')] = "#{sign} #{metric_by_grades[grade][:threshold].to_i}"
        end
      end

      REFERENCES_STUB = {
        'ClassA' => {threshold: '0', range: []},
        'ClassB' => {threshold: '0', range: []},
        'ClassC' => {threshold: '0', range: []},
        'ClassD' => {threshold: '0', range: []},
        'ClassE' => {threshold: '0', range: []},
      }

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

        ranks = classes.each_with_object([]) do |klass, preview|
          grade = klass.downcase.sub(/class/, '')
          result = {
            type: grade,
            year: ' N/A ',
            total: ' N/A '
          }

          [:year, :total].each do |section_type|
            next if section == :not_found # this should not happen
            reference_section = [section, section_type].join('_')

            metric_by_grades = @reference[reference_section.to_sym][metric.to_s]
            next unless metric_by_grades

            sign = metric_by_grades[classes.first][:range].include?(-Float::INFINITY) ? '&lt;&nbsp;' : '&gt;&nbsp;'
            value = decorate_value(metric, metric_by_grades[klass][:threshold])

            result[section_type] = "#{sign} #{value}"
          end

          preview << result
        end

        {
          title: Ossert.t(metric),
          description: Ossert.descr(metric),
          ranks: ranks
        }
      end

      # Fast preview graph
      # [
      #   {"title":"Jan - Mar 2016","type":"a","values":[10,20]},
      #   {"title":"Apr - Jun 2016","type":"b","values":[20,25]},
      #   {"title":"Jul - Sep 2016","type":"c","values":[25,35]},
      #   {"title":"Oct - Dec 2016","type":"d","values":[35,50]},
      #   {"title":"Next year","type":"e","values":[50,10]}
      # ]
      def fast_preview_graph_data
        return @fast_preview_graph_data if defined? @fast_preview_graph_data
        check_results = 4.downto(0).map do |last_year_offset|
          Ossert::Classifiers::Growing.current.check(@project, last_year_offset)
        end

        @fast_preview_graph_data = {popularity: [], maintenance: [], maturity: []} # replace with config

        check_results.each_with_index do |check_result, offset|
          check_result.each do |check, results|
            gain = results[:gain].to_f.round(2)
            @fast_preview_graph_data[check] << {
              title: last_quarters_bounds(offset),
              type: results[:mark].downcase,
              values: [gain]
            }

            @fast_preview_graph_data[check][offset - 1][:values] << gain if offset > 0
          end
        end

        @fast_preview_graph_data
      end

      def last_quarters_bounds(last_year_offset)
        date = Time.current.utc - (last_year_offset * 3).months

        [date.beginning_of_quarter.strftime('%b'),
         date.end_of_quarter.strftime('%b %Y')].join(' - ')
      end
    end
  end
end
