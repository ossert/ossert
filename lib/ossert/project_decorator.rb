module Ossert
  class ProjectDecorator
    attr_reader :project

    def initialize(project)
      @project = project
      @reference = Ossert::Classifiers::Growing.current.reference_values_per_class
    end

    def with_reference(text, value, metric, type)
      reference = @reference[type][metric].inject('NaN') do |acc, (ref, ref_values)|
        Range.new(*ref_values).cover?(value) ? ref : acc
      end
      "#{text} (#{reference})"
    end

    def percent(value)
      "#{value} %"
    end

    def date(value)
      Time.at(value).strftime('%d-%m-%Y')
    end

    def years(value)
      "#{(value / 365.0).ceil} years"
    end

    def agility_total
      @project.agility.total.metrics_to_hash.each_with_object({}) do |(metric, value), res|
        res[metric] = case metric
                      when /percent/
                        with_reference(
                          percent(value),
                          metric,
                          :agility_total
                        )
                      when /(date|period)/
                        with_reference(
                          date(value),
                          metric,
                          :agility_total
                        )
                      when /period/
                        with_reference(
                          years(value),
                          metric,
                          :agility_total
                        )
                      when /count/
                        with_reference(
                          value.to_i,
                          metric,
                          :agility_total
                        )
                      else
                        with_reference(
                          value,
                          metric,
                          :agility_total
                        )
                      end
      end
    end

    def agility_quarter(quarter)
      quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter
      @project.agility.quarters[quarter].metrics_to_hash.each_with_object({}) do |(metric, value), res|
        res[metric] = case metric
                      when /percent/
                        with_reference(
                          percent(value),
                          metric,
                          :agility_quarter
                        )
                      when /(date|period)/
                        with_reference(
                          date(value),
                          metric,
                          :agility_quarter
                        )
                      when /period/
                        with_reference(
                          years(value),
                          metric,
                          :agility_quarter
                        )
                      when /count/
                        with_reference(
                          value.to_i,
                          metric,
                          :agility_quarter
                        )
                      else
                        with_reference(
                          value,
                          metric,
                          :agility_quarter
                        )
                      end
      end
    end

    def community_total
      @project.community.total.metrics_to_hash.each_with_object({}) do |(metric, value), res|
        res[metric] = case metric
                      when /percent/
                        with_reference(
                          percent(value),
                          metric,
                          :community_total
                        )
                      when /(date|period)/
                        with_reference(
                          date(value),
                          metric,
                          :community_total
                        )
                      when /period/
                        with_reference(
                          years(value),
                          metric,
                          :community_total
                        )
                      when /count/
                        with_reference(
                          value.to_i,
                          metric,
                          :community_total
                        )
                      else
                        with_reference(
                          value,
                          metric,
                          :community_total
                        )
                      end
      end
    end

    def community_quarter
      quarter = Time.at(quarter).to_date.to_time(:utc).beginning_of_quarter
      @project.community.quarters[quarter].metrics_to_hash.each_with_object({}) do |(metric, value), res|
        res[metric] = case metric
                      when /percent/
                        with_reference(
                          percent(value),
                          metric,
                          :community_quarter
                        )
                      when /(date|period)/
                        with_reference(
                          date(value),
                          metric,
                          :community_quarter
                        )
                      when /period/
                        with_reference(
                          years(value),
                          metric,
                          :community_quarter
                        )
                      when /count/
                        with_reference(
                          value.to_i,
                          metric,
                          :community_quarter
                        )
                      else
                        with_reference(
                          value,
                          metric,
                          :community_quarter
                        )
                      end
      end
    end

    def issues_active_percent
      with_reference(
        percent(project.agility.total.issues_active_percent),

      )
    end
  end
end
