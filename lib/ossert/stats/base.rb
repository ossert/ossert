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

        def define_counts(*attributes)
          Array.wrap(attributes).each do |metric|
            define_method("#{metric}_count") { public_send(metric).count }
          end
        end

        def define_percent(*attributes, default_value: 0)
          Array.wrap(attributes).each do |metric|
            type = metric.to_s.split('_').first
            define_method("#{metric}_percent") do
              value = public_send(metric)
              total_count = public_send("#{type}_all").count
              return default_value if total_count.zero?
              ((value.count.to_d / total_count.to_d) * 100).round(2)
            end
          end
        end
      end

      def initialize
        self.class.config['attributes'].each do |var, type|
          send "#{var}=", Kernel.const_get(type).new if type
        end
      end

      def median(values)
        values = values.to_a.sort
        if values.count.odd?
          values[values.count/2]
        elsif values.count.zero?
          0
        else
          ((values[values.count/2 - 1] + values[values.count/2]) / 2.0).to_i
        end
      end

      def metric_values
        self.class.metrics.map { |metric| public_send(metric).to_f }
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
