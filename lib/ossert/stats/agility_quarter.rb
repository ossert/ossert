module Ossert
  module Stats
    class AgilityQuarter < Base
      self.section = 'agility'
      self.section_type = 'quarter'
      create_attributes_accessors

      [
        :issues_active, :issues_closed,
        :pr_active, :pr_closed, :pr_merged
      ].each do |metric|
        type = metric.to_s.split('_').first
        define_method("#{metric}_percent") do
          value = public_send(metric)
          total_count = public_send("#{type}_all").count
          return 0 if total_count.zero?
          ((value.count.to_d / total_count.to_d) * 100).round(2)
        end
      end

      [:issues_active, :pr_active, :issues_closed, :issues_actual,
       :pr_closed, :issues_all, :pr_all, :pr_actual].each do |metric|
        define_method("#{metric}_count") { public_send(metric).count }
      end

      def issues_processed_in_avg
        values = issues_processed_in_days.to_a.sort
        if values.count.odd?
          values[values.count/2]
        elsif values.count.zero?
          0
        else
          ((values[values.count/2 - 1] + values[values.count/2]) / 2.0).to_i
        end
      end

      def pr_processed_in_avg
        values = pr_processed_in_days.to_a.sort
        if values.count.odd?
          values[values.count/2]
        elsif values.count.zero?
          0
        else
          ((values[values.count/2 - 1] + values[values.count/2]) / 2.0).to_i
        end
      end

      def issues_active
        (issues_open + issues_actual) - issues_closed
      end

      def issues_all
        issues_open + issues_closed + issues_actual
      end

      def pr_active
        (pr_open + pr_actual) - pr_closed
      end

      def pr_all
        pr_open + pr_closed + pr_actual
      end

      def releases_count
        [releases_total_rg.count, releases_total_gh.count].max
      end

    end
  end
end
