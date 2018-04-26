# frozen_string_literal: true

require 'ossert/stats/base'
require 'ossert/stats/agility_total'
require 'ossert/stats/agility_quarter'
require 'ossert/stats/community_total'
require 'ossert/stats/community_quarter'

module Ossert
  module Stats
    # @return [Numeric] specifies too long interval border for quarter
    PER_QUARTER_TOO_LONG = (5.years / 1.day).to_i
    # @return [Numeric] specifies too long interval border for year
    PER_YEAR_TOO_LONG = PER_QUARTER_TOO_LONG / 4
    # @return [Numeric] specifies number of seconds in the day
    SECONDS_IN_DAY = 86_400
    # @return [Date] specifies UNIX epoch start
    ZERO_DAY = Date.new(1970, 1, 1)

    # Try to find data section for given metric name.
    #
    # @param metric [String] name to search for.
    # @return [Symbol] name of data section or `:not_found`.
    def guess_section_by_metric(metric)
      found_section = :not_found
      section_by_metric.each do |section, metrics|
        next unless metrics.include? metric
        found_section = section
        break
      end
      found_section
    end
    # (see #guess_section_by_metric)
    module_function :guess_section_by_metric

    # @return [Hash] of metrics names indexed by data section they
    #   belong to.
    def section_by_metric
      @section_by_metric ||= {
        agility: AgilityTotal.metrics + AgilityQuarter.metrics,
        community: CommunityTotal.metrics + CommunityQuarter.metrics
      }
    end
    # (see #section_by_metric)
    module_function :section_by_metric

    # @return [Array<String>] list of Popularity metrics names
    def popularity_metrics
      @popularity_metrics ||= (::Settings['stats']['community']['quarter']['metrics'] +
                               ::Settings['stats']['community']['total']['metrics']).uniq
    end
    # (see #popularity_metrics)
    module_function :popularity_metrics

    # @return [Array<String>] list of Maintenance metrics names
    def maintenance_metrics
      @maintenance_metrics ||= (::Settings['stats']['agility']['quarter']['metrics'] +
                                ::Settings['stats']['agility']['total']['metrics']).uniq
    end
    # (see #maintenance_metrics)
    module_function :maintenance_metrics

    # @return [Array<String>] list of Maturity metrics names
    def maturity_metrics
      @maturity_metrics ||= (::Settings['classifiers_growth']['metrics']['maturity']['last_year'].keys +
                             ::Settings['classifiers_growth']['metrics']['maturity']['total'].keys).uniq
    end
    # (see #maturity_metrics)
    module_function :maturity_metrics
  end
end
