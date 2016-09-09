require 'rom-repository'
require 'rom-sql'

module Ossert
  module Saveable
    # DB = Sequel.connect(ENV.fetch("DATABASE_URL")) # memory database, requires sqlite3
    UNUSED_REFERENCE = 'unused'.freeze

    def filename
      self.class.name
    end

    def read
      fail NotImplementedError
    end

    def assign(saved_data)
      fail NotImplementedError
    end

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

    def deserialize(stored_prj)
      coerce_value = (->(value) {
        return Set.new(value) if value.is_a? Array
        return DateTime.parse(value) rescue value
      })

      agility_total_stat = AgilityTotalStat.new
      JSON.parse(stored_prj.agility_total_data).each_pair do |metric, value|
        agility_total_stat.send "#{metric}=", coerce_value.call(value)
      end

      agility_quarters_stat = QuartersStore.new(AgilityQuarterStat)
      JSON.parse(stored_prj.agility_quarters_data).each_pair do |time, metrics|
        metrics.each_with_object(agility_quarters_stat[time.to_i]) do |(metric, value), quarter|
          quarter.send "#{metric}=", coerce_value.call(value)
        end
      end

      community_total_stat = CommunityTotalStat.new
      JSON.parse(stored_prj.community_total_data).each_pair do |metric, value|
        community_total_stat.send "#{metric}=", coerce_value.call(value)
      end

      community_quarters_stat = QuartersStore.new(CommunityQuarterStat)
      JSON.parse(stored_prj.community_quarters_data).each_pair do |time, metrics|
        metrics.each_with_object(community_quarters_stat[time.to_i]) do |(metric, value), quarter|
          quarter.send "#{metric}=", coerce_value.call(value)
        end
      end

      Ossert::Project.new(
        stored_prj.name,
        stored_prj.github_name,
        stored_prj.rubygems_name,
        stored_prj.reference,
        agility: Ossert::Project::Agility.new(
          quarters: agility_quarters_stat, total: agility_total_stat
        ),
        community: Ossert::Project::Community.new(
          quarters: community_quarters_stat, total: community_total_stat
        )
      )
    end

    def load_all
      # TODO: Later we'll need pagination here!
      repo.all.map do |stored_prj|
        deserialize(stored_prj)
      end
    end

    def dump
      projects.each(&:dump)
    end
  end
end

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
end
