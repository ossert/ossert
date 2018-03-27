# frozen_string_literal: true

require 'twitter'
require_relative 'search_results_validator'

module Ossert
  module Twitter
    # Patches Twitter::SearchResults class from twitter gem to
    # validate json schema
    module SearchResultsPatch
      def self.apply_json_validator!
        patch_module = Module.new do
          def attrs=(attrs)
            ::Ossert::Twitter::SearchResultsValidator.call!(attrs) if SearchResultsValidator.enabled?
            super(attrs)
          end
        end
        ::Twitter::SearchResults.prepend(patch_module)
      end
    end
  end
end

Ossert::Twitter::SearchResultsPatch.apply_json_validator!
