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
          Array.wrap(attributes).each do |metric|
            define_method("#{metric}_int") { public_send(metric).to_i }
          end
        end

        def define_counts(*attributes)
          Array.wrap(attributes).each do |metric|
            define_method("#{metric}_count") { public_send(metric).count }
          end
        end

        def define_percent(attributes, default_value: 0)
          attributes.to_h.each do |metric, total|
            define_method("#{metric}_percent") do
              total_count = public_send(total).count
              return default_value if total_count.zero?

              ((public_send(metric).count.to_d / total_count.to_d) * 100).round(2)
            end
          end
        end
      end

      def <<(other_stats)
        self.class.attributes_names.each do |attr|
          next unless current_value = other_stats.send(attr)
          send("#{attr}=", send(attr) + current_value)
          send(attr).uniq! if send(attr).respond_to?(:uniq)
        end
        self
      end

      def initialize
        self.class.attributes.each do |var, type|
          send "#{var}=", Kernel.const_get(type).new if type
        end
      end

      def median(values, default_value: 0)
        values = Array(values).sort
        return default_value if (count = values.count).zero?

        middle_idx = values.count / 2
        return values[middle_idx] if count.odd?

        (values[middle_idx - 1] + values[middle_idx]) / 2
      end

      def metric_values
        self.class.metrics.map { |metric| public_send(metric).to_f }
      end

      def metrics_to_hash
        self.class.metrics.each_with_object({}) do |var, result|
          result[var] = send(var)
          # result[var] = if (value = send(var)).is_a? Array
          #                 value.uniq
          #               else
          #                 value
          #               end
        end
      end

      def to_hash
        self.class.attributes_names.each_with_object({}) do |var, result|
          result[var] = if (value = send(var)).is_a? Array
                          value.uniq
                        else
                          value
                        end
        end
      end

      def to_json
        MultiJson.dump(to_hash)
      end
    end
  end
end
