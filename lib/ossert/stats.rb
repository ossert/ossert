# frozen_string_literal: true
require 'ossert/stats/base'
require 'ossert/stats/agility_total'
require 'ossert/stats/agility_quarter'
require 'ossert/stats/community_total'
require 'ossert/stats/community_quarter'

module Ossert
  module Stats
    def guess_section_by_metric(metric)
      found_section = :not_found
      section_by_metric.each do |section, metrics|
        next unless metrics.include? metric
        found_section = section
        break
      end
      found_section
    end
    module_function :guess_section_by_metric

    def section_by_metric
      @section_by_metric ||= {
        agility: AgilityTotal.metrics + AgilityQuarter.metrics,
        community: CommunityTotal.metrics + CommunityQuarter.metrics
      }
    end
    module_function :section_by_metric
  end
end
