# frozen_string_literal: true

require 'oj'
require 'multi_json'

class NameException < Sequel::Model(:exceptions)
  set_primary_key [:name]
  class << self
    alias by_name []
  end
end
::NameException.unrestrict_primary_key

class TwitterMetrics < Sequel::Model(:twitter_metrics)
end

class Classifier < Sequel::Model
  set_primary_key [:section]
  # Calling a dataset filtering method with multiple arguments or an array where the first argument/element is a string is deprecated and will be removed in Sequel 5.
  # Use Sequel.lit("updated_at > ?", 2017-07-03 15:47:28 +0500) to create an SQL fragment expression and pass that to the dataset filtering method, or use the auto_literal_strings extension.
  def self.actual?
    where(Sequel.lit('updated_at > ?', 1.month.ago)).count.positive?
  end
end
::Classifier.unrestrict_primary_key

class Project < Sequel::Model
  set_primary_key [:name]

  # Sequel::Model.def_dataset_method is deprecated and will be removed in Sequel 5.  Define the method inside a dataset_module block, or use the def_dataset_method_plugin.
  dataset_module do
    def random(count)
      where(Sequel.lit('github_name NOT IN (?, ?)', Ossert::NO_GITHUB_NAME, Ossert::NOT_FOUND_GITHUB_NAME))
        .order(Sequel.lit('random()'))
        .limit(count)
    end
  end

  class << self
    def later_than(id)
      where('id >= ?', id)
    end

    def referenced
      #  Calling a dataset filtering method with multiple arguments or an array where the first argument/element is a string is deprecated and will be removed in Sequel 5.
      #  Use Sequel.lit("reference <> ? AND github_name NOT IN (?, ?)", "unused", "__unknown__", "__not_found__") to create an SQL fragment expression and pass that to the dataset filtering method, or use the auto_literal_strings extension.
      where(
        Sequel.lit(
          'reference <> ? AND github_name NOT IN (?, ?)',
          Ossert::Saveable::UNUSED_REFERENCE,
          Ossert::NO_GITHUB_NAME,
          Ossert::NOT_FOUND_GITHUB_NAME
        )
      )
    end
  end

  class Unpacker
    def initialize(stored_project)
      @stored_project = stored_project
    end

    def self.process(stored_project)
      new(stored_project).process
    end

    def process
      %i[agility community].each_with_object(process_meta) do |stats_type, result|
        result[stats_type] = factory_project_stats(stats_type).new(
          [Total, Quarter].each_with_object({}) do |unpacker_type, stats_result|
            section_unpacker = unpacker_type.new(@stored_project, stats_type)
            stats_result[section_unpacker.section] = section_unpacker.process
          end
        )
      end
    ensure
      @stored_project = nil
    end

    private

    def process_meta
      result = {
        created_at: @stored_project.created_at,
        updated_at: @stored_project.updated_at
      }
      result[:meta] = if @stored_project.meta_data.present?
                        MultiJson.load(@stored_project.meta_data)
                      else
                        {}
                      end

      result
    end

    def factory_project_stats(stats_type)
      Kernel.const_get "Ossert::Project::#{stats_type.to_s.capitalize}"
    end

    class Base
      def initialize(stored_project, stats_type)
        @stats_type = stats_type
        @stored_project = stored_project
      end

      def coerce_value(value)
        DateTime.parse(value)
      rescue StandardError
        value
      end

      def stored_data
        @stored_project.send("#{@stats_type}_#{section}_data")
      end
    end

    class Total < Base
      def section
        :total
      end

      def new_stats_object
        Kernel.const_get("Ossert::Stats::#{@stats_type.capitalize}Total").new
      end

      def process
        MultiJson.load(
          stored_data
        ).each_with_object(new_stats_object) do |(metric, value), stats_object|
          stats_object.send "#{metric}=", coerce_value(value)
        end
      end
    end

    class Quarter < Base
      def section
        :quarters
      end

      def new_stats_object
        Ossert::QuartersStore.new(
          "Ossert::Stats::#{@stats_type.capitalize}Quarter"
        )
      end

      def process
        MultiJson.load(
          stored_data
        ).each_with_object(new_stats_object) do |(time, metrics), quarter_store|
          metrics.each_with_object(quarter_store[time.to_i]) do |(metric, value), quarter|
            quarter.send "#{metric}=", coerce_value(value)
          end
        end
      end
    end
  end
end
::Project.unrestrict_primary_key
