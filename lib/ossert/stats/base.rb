module Ossert
  module Stats
    class Base
      class << self
        attr_accessor :section, :section_type

        def config
          @config ||= ::Settings['stats'][section][section_type]
        end

        def attributes
          @attributes ||= config['attributes'].keys
        end

        def aggregated_metrics
          @aggregated_metrics ||= config['aggregated_metrics']
        end

        def metrics
          @metrics ||= config['metrics']
        end

        def create_attributes_accessors
          attr_accessor(*attributes)
        end
      end

      def initialize
        self.class.config['attributes'].each do |var, type|
          send "#{var}=", Kernel.const_get(type).new if type
        end
      end

      def metric_values
        self.class.metrics.map { |metric| public_send(metric).to_f }
      end

      def metric_values
        self.class.metrics.map do |metric|
          public_send(metric).to_f
          # metric.to_s =~ /(percent|avg)/ ? value / 3.0 : value
        end
      end

      def metrics_to_hash
        self.class.metrics.each_with_object({}) do |var, result|
          value = send(var)
          if value.is_a? Set
            result[var] = value.to_a
          else
            result[var] = value
          end
        end
      end

      def to_hash
        self.class.attributes.each_with_object({}) do |var, result|
          if (value = send(var)).is_a? Set
            result[var] = value.to_a
          else
            result[var] = value
          end
        end
      end

      def to_json
        JSON.generate(to_hash)
      end
    end
  end
end
