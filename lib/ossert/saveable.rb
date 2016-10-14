module Ossert
  module Saveable
    UNUSED_REFERENCE = 'unused'.freeze

    def repo
      ProjectRepo.new(Ossert.rom)
    end

    def load_by_name(name)
      stored_prj = repo[name]
      deserialize(stored_prj) if stored_prj
    end

    def load_referenced
      repo.referenced.map do |stored_prj|
        deserialize(stored_prj)
      end
    end

    def load_later_than(id)
      repo.later_than(id).map do |stored_prj|
        deserialize(stored_prj)
      end
    end

    def cleanup_referencies!
      repo.command(:update, repo.projects).call(reference: UNUSED_REFERENCE)
    end

    def deserialize(stored_project)
      Ossert::Project.new(
        stored_project.name,
        stored_project.github_name,
        stored_project.rubygems_name,
        stored_project.reference,
        Unpacker.new(stored_project).process
      )
    end

    # TODO: Later we'll need pagination here!
    def load_all
      repo.all.map do |stored_prj|
        deserialize(stored_prj)
      end
    end

    def dump
      projects.each(&:dump)
    end

    class Unpacker
      def initialize(stored_project)
        @stored_project = stored_project
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
            [Total, Quarter].each_with_object({}) do |section_type, stats_result|
              section_unpacker = section_type.new(@stored_project, stats_type)
              stats_result[section_unpacker.to_key] = section_unpacker.process
            end
          )
        end

        result
      end

      private

      def factory_project_stats(stats_type)
        case stats_type
        when :agility
          Ossert::Project::Agility
        when :community
          Ossert::Project::Community
        else
          fail ArgumentError
        end
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
          @stored_project.send("#{@stats_type}_#{to_key}_data")
        end
      end

      class Total < Base
        def to_key
          :total
        end

        def stored_data
          @stored_project.send("#{@stats_type}_total_data")
        end

        def new_stats_object
          case @stats_type
          when :agility
            Stats::AgilityTotal.new
          when :community
            Stats::CommunityTotal.new
          else
            fail ArgumentError
          end
        end

        def process
          JSON.parse(stored_data).each_with_object(new_stats_object) do |(metric, value), stats_object|
            stats_object.send "#{metric}=", coerce_value(value)
          end
        end
      end

      class Quarter < Base
        def to_key
          :quarters
        end

        def new_stats_object
          case @stats_type
          when :agility
            Ossert::QuartersStore.new(Stats::AgilityQuarter)
          when :community
            Ossert::QuartersStore.new(Stats::CommunityQuarter)
          else
            fail ArgumentError
          end
        end

        def process
          JSON.parse(stored_data).each_with_object(new_stats_object) do |(time, metrics), quarter_store|
            metrics.each_with_object(quarter_store[time.to_i]) do |(metric, value), quarter|
              quarter.send "#{metric}=", coerce_value(value)
            end
          end
        end
      end
    end
  end
end
