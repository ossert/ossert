# frozen_string_literal: true
module Ossert
  module Stats
    class Base
      class << self
        attr_accessor :section, :section_type

        def config
          @config ||= ::Settings['stats'][section][section_type]
        end

        def attributes
          @attributes ||= config['attributes']
        end

        def uniq_attributes
          @uniq_attributes ||= config['uniq_attributes'].to_a
        end

        def absolute_attributes
          @absolute_attributes ||= config['absolute_attributes'].to_a
        end

        def attributes_names
          @attributes_names ||= attributes.keys
        end

        def metrics
          @metrics ||= config['metrics']
        end

        def create_attributes_accessors
          attr_accessor(*attributes_names)
        end

        def define_ints(*attributes)
          iterate_attributes(attributes) do |metric|
            define_method("#{metric}_int") { public_send(metric).to_i }
          end
        end

        def define_counts(*attributes)
          iterate_attributes(attributes) do |metric|
            define_method("#{metric}_count") { public_send(metric).count }
          end
        end

        def iterate_attributes(attributes)
          Array.wrap(attributes).each { |metric| yield metric }
        end

        def define_percent(attributes, default_value: 0)
          attributes.to_h.each do |metric, total|
            define_method("#{metric}_percent") do
              total_count = get_count(total)
              return default_value if total_count.zero?
              metric_count = get_count(metric)

              (metric_count.to_d / total_count.to_d * 100).round(2)
            end
          end
        end
      end

      def <<(other_stats)
        self.class.attributes_names.each do |attr|
          next unless (other_value = other_stats.instance_variable_get("@#{attr}"))
          new_value = other_value
          new_value += instance_variable_get("@#{attr}") unless self.class.absolute_attributes.include?(attr)
          new_value.uniq! if self.class.uniq_attributes.include?(attr)

          instance_variable_set("@#{attr}", new_value)
        end
        self
      end

      def initialize
        self.class.attributes.each do |var, type|
          instance_variable_set("@#{var}", Kernel.const_get(type).new) if type
        end
      end

      def median(values, default_value: 0)
        values = Array(values).sort
        return default_value if (count = values.count).zero?

        middle_idx = values.count / 2
        return values[middle_idx] if count.odd?

        (values[middle_idx - 1] + values[middle_idx]) / 2
      end

      def get_count(metric)
        count_method = "#{metric}_count"
        if self.class.method_defined? count_method
          public_send(count_method)
        else
          public_send(metric).count
        end
      end

      def metric_values
        self.class.metrics.map { |metric| public_send(metric).to_f }
      end

      def metrics_to_hash
        self.class.metrics.each_with_object({}) do |var, result|
          result[var] = send(var)
        end
      end

      def to_hash
        self.class.attributes_names.each_with_object({}) do |var, result|
          value = send(var)
          value.uniq! if self.class.uniq_attributes.include?(var)
          result[var] = value
        end
      end

      def to_json
        MultiJson.dump(self)
      end
    end
  end
end
