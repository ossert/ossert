# frozen_string_literal: true
module Ossert
  module Stats
    # A base class for storing and handling values extracted from the projects.
    #
    # All metric-specific methods and variables are creating in runtime via
    # class instance methods "define_*" (intended to use in subclasses) and
    # in the constructor.
    class Base
      class << self
        attr_accessor :section, :section_type

        # @!attribute [rw] section
        # name of the metric section (agility or community)
        # @return [String] name of the section

        # @!attribute [rw] section_type
        # name of the metric section type (quarters or total)
        # @return [String] name of the type

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

        # Iterate through the list of attributes
        #
        # @param attributes [String, Array<String>] attributes to iterate
        # @yieldparam metric [String] one of the attributes
        #
        # @return [nil] Not specified
        def iterate_attributes(attributes)
          Array.wrap(attributes).each { |metric| yield metric }
        end

        def define_ints(*attributes)
          iterate_attributes(attributes) do |metric|
            define_method("#{metric}_int") { public_send(metric).to_i }
          end
        end

        # Define length helpers for attributes in runtime
        #
        # @param attributes [Array<String>, Array<Symbol>]
        #   A list of attributes
        #
        # The method defines instance methods for given metrics
        # with a template name like "%metric_name%_count".
        # It is assumed that the attributes list contains
        # only names of Array-like attributes.
        #
        # @example
        #   class Example < Base
        #     define_counts(:questions, :branches)
        #     # ...
        #   end
        #
        #   Example.new.questions_count #=> 42
        #
        # @return [nil] Not specified
        def define_counts(*attributes)
          iterate_attributes(attributes) do |metric|
            define_method("#{metric}_count") { public_send(metric).count }
          end
        end

        # Define percentage helpers for attributes in runtime
        #
        # @param attributes [Hash<Symbol, Symbol>, Hash<String, String>]
        #   A list of attributes where key is a considered as a part
        #   of the value.
        #
        # The method defines instance methods for given metrics
        # with a template name like "%key_name%_percent".
        # It is assumed that the attributes list contains
        # only names of Array-like attributes *OR* the method
        # with name "%metric_name%_count" must be defined
        # explicitly for the instance.
        # The important note - the generated method will
        # calculate percent basing on a number of values
        # in given metrics, not on the value of the metrics
        #
        # @example
        #   class Example < Base
        #     define_percent({closed_branches: :branches})
        #     # ...
        #   end
        #
        #   Example.new.closed_branches_percent #=> 42.22
        #
        # @return [nil] Not specified
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

        # Define median helpers for attributes in runtime
        #
        # @param attributes [Array<String>, Array<Symbol>]
        #   A list of attributes
        #
        # The method defines instance methods for given metrics
        # with a template name like "%metric_name%_median".
        # It is assumed that the attributes list contains
        # only names of Array-like attributes.
        #
        # @example
        #   class Example < Base
        #     define_medians(:questions_view)
        #     # ...
        #   end
        #
        #   Example.new.questions_view_median #=> 42
        #
        # @return [nil] Not specified
        def define_median(*attributes)
          iterate_attributes(attributes) do |metric|
            define_method("#{metric}_median") { median(public_send(metric)) }
          end
        end

        # Define average helpers for attributes in runtime
        #
        # @param attributes [Array<String>, Array<Symbol>]
        #   A list of attributes
        #
        # The method defines instance methods for given metrics
        # with a template name like "%metric_name%_average".
        # It is assumed that the attributes list contains
        # only names of Array-like attributes.
        #
        # @example
        #   class Example < Base
        #     define_average(:questions_view)
        #     # ...
        #   end
        #
        #   Example.new.questions_view_average #=> 4.2
        #
        # @return [nil] Not specified
        def define_average(*attributes)
          iterate_attributes(attributes) do |metric|
            define_method("#{metric}_avg") do
              if (stat = public_send(metric).compact).empty?
                0.0
              else
                stat.reduce(:+) / stat.size.to_f
              end
            end
          end
        end

        # Define sum helpers for attributes in runtime
        #
        # @param attributes [Array<String>, Array<Symbol>]
        #   A list of attributes
        #
        # The method defines instance methods for given metrics
        # with a template name like "%metric_name%_sum".
        # It is assumed that the attributes list contains
        # only names of Array-like attributes.
        #
        # @example
        #   class Example < Base
        #     define_sum(:questions_view)
        #     # ...
        #   end
        #
        #   Example.new.questions_view_sum #=> 42
        #
        # @return [nil] Not specified
        def define_sum(*attributes)
          iterate_attributes(attributes) do |metric|
            define_method("#{metric}_sum") do
              public_send(metric).compact.reduce(:+) || 0
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

      # Create instance of the class Base
      #
      # Also initiates all instance variables listed in "/config/stats"
      # for a given section of metrics.
      #
      # @return [Base] instance of the class
      def initialize
        self.class.attributes.each do |var, type|
          instance_variable_set("@#{var}", Kernel.const_get(type).new) if type
        end
      end

      # Get a median value of elements
      #
      # @param values [Array<Numeric>] numeric values to search through
      # @param default_value [Numeric] default result for empty values
      #
      # @return [Numeric] Median value for the given values
      def median(values, default_value: 0)
        values = Array(values.compact).sort
        return default_value if (count = values.count).zero?

        middle_idx = values.count / 2
        return values[middle_idx] if count.odd?

        (values[middle_idx - 1] + values[middle_idx]) / 2
      end

      # Get a number of elements in a given attribute
      #
      # @param metric [String, Symbol] a name of an Array-like attribute to count
      #
      # @return [Integer] Number of elements
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
