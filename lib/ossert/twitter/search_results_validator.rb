# frozen_string_literal: true

require 'json-schema'

module Ossert
  module Twitter
    # Validates tweets list user json-schema when enabled
    class SearchResultsValidator
      class << self
        def validate!
          enable!
          yield
        rescue StandardError => e
          disable!
          raise e
        ensure
          disable!
        end

        def enabled?
          Thread.current[name]
        end

        def call!(json)
          schema_file = File.join(
            Ossert::Config::CONFIG_ROOT, 'twitter', 'search_results_schema.json')
          JSON::Validator.validate!(schema_file, json)
        end

        private

        def enable!
          Thread.current[name] = true
        end

        def disable!
          Thread.current[name] = false
        end
      end
    end
  end
end
