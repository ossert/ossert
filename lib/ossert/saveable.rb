module Ossert
  module Saveable
    # DB = Sequel.connect(ENV.fetch("DATABASE_URL")) # memory database, requires sqlite3

    def filename
      self.class.name
    end

    def read
      fail NotImplementedError
    end

    def assign(saved_data)
      fail NotImplementedError
    end

    def load
      conf = ROM::Configuration.new(:sql, ENV.fetch("DATABASE_URL"))
      conf.register_relation(Projects)
      rom = ROM.container(conf)
      ProjectRepo.new(rom).all.each do |stored_prj|
        coerce_value = (->(value) {
          return Set.new(value) if value.is_a? Array
          return Date.parse(value) rescue value
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
      self
    end

    def dump
      conf = ROM::Configuration.new(:sql, ENV.fetch("DATABASE_URL"))
      conf.register_relation(Projects)
      rom = ROM.container(conf)
      project_repo = ProjectRepo.new(rom)

      projects.each do |prj|
        saved_prj = project_repo[prj.name]
        if saved_prj
          project_repo.update(
            prj.name,
            name: prj.name,
            github_name: prj.gh_alias,
            rubygems_name: prj.rg_alias,
            reference: prj.reference,
            agility_total_data: prj.agility.total.to_json,
            agility_quarters_data: prj.agility.quarters.to_json,
            community_total_data: prj.community.total.to_json,
            community_quarters_data: prj.community.quarters.to_json
          )
        else
          project_repo.create(
            name: prj.name,
            github_name: prj.gh_alias,
            rubygems_name: prj.rg_alias,
            reference: prj.reference,
            agility_total_data: prj.agility.total.to_json,
            agility_quarters_data: prj.agility.quarters.to_json,
            community_total_data: prj.community.total.to_json,
            community_quarters_data: prj.community.quarters.to_json
          )
        end
      end
      # existance_backup("data/#{filename}.json")
      # File.open("data/#{filename}.json","w") do |f|
      #   f.write(Oj.dump(read))
      # end
    end

    def existance_backup(filename)
      return unless File.exists?(filename)
      FileUtils.cp(filename, "#{filename}.#{Time.now.strftime('%d%m%Y-%H%M%S.%L')}")
    end
  end
end

class Projects < ROM::Relation[:sql]
  def by_name(name)
    where(name: name)
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
end
