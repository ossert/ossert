require 'rom-repository'
require 'rom-sql'

class Exceptions < ROM::Relation[:sql]
  def by_name(name)
    where(name: name)
  end
end

class ExceptionsRepo < ROM::Repository[:exceptions]
  commands :create, update: :by_name, delete: :by_name

  def [](name)
    exceptions.by_name(name).one
  end

  def all
    exceptions.to_a
  end

  def all_by_names
    all.index_by(&:name)
  end
end

class Projects < ROM::Relation[:sql]
  def by_name(name)
    where(name: name)
  end

  def later_than(id)
    where('id >= ?', id)
  end

  def referenced
    where('reference <> ?', Ossert::Saveable::UNUSED_REFERENCE)
  end
end

class ProjectRepo < ROM::Repository[:projects]
  commands :create, update: :by_name, delete: :by_name

  def [](name)
    projects.by_name(name).one
  end

  def all
    projects.to_a
  end

  def later_than(id)
    projects.later_than(id).to_a
  end

  def referenced
    projects.referenced.to_a
  end

  class Unpacker
    def initialize(stored_project)
      @stored_project = stored_project
    end

    def self.process(stored_project)
      new(stored_project).process
    end

    def process
      result = {}
      result[:meta] = if @stored_project.meta_data.present?
                        JSON.parse(@stored_project.meta_data)
                      else
                        {}
                      end

      [:agility, :community].each do |stats_type|
        result[stats_type] = factory_project_stats(stats_type).new(
          [Total, Quarter].each_with_object({}) do |unpacker_type, stats_result|
            section_unpacker = unpacker_type.new(@stored_project, stats_type)
            stats_result[section_unpacker.section] = section_unpacker.process
          end
        )
      end

      result
    end

    private

    def factory_project_stats(stats_type)
      Object.const_get "Ossert::Project::#{stats_type.to_s.capitalize}"
    end

    class Base
      def initialize(stored_project, stats_type)
        @stats_type = stats_type
        @stored_project = stored_project
      end

      def coerce_value(value)
        return Set.new(value) if value.is_a? Array
        return DateTime.parse(value) rescue value
      end

      def stored_data
        @stored_project.send("#{@stats_type}_#{section}_data")
      end
    end

    class Total < Base
      def section
        :total
      end

      def stored_data
        @stored_project.send("#{@stats_type}_total_data")
      end

      def new_stats_object
        Kernel.const_get("Ossert::Stats::#{@stats_type.capitalize}Total").new
      end

      def process
        JSON.parse(
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
          Object.const_get "Ossert::Stats::#{@stats_type.capitalize}Quarter"
        )
      end

      def process
        JSON.parse(
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
