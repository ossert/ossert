module Ossert
  module Stats
    class Base
      class << self
        attr_accessor :section, :section_type
      end

      def self.config
        @config ||= ::Settings['stats'][section][self.section_type]
      end

      def self.attributes
        @attributes ||= config['attributes'].keys
      end

      def self.metrics
        @metrics ||= config['metrics']
      end

      def self.create_attributes_accessors
        attr_accessor(*attributes)
      end
    end
  end
end
