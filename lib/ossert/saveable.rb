module Ossert
  module Saveable
    UNUSED_REFERENCE = 'unused'.freeze

    def self.included(base)
      base.extend(ClassMethods)
    end

    def dump_attribute(attriibute, value)
      with_repo do |repo|
        if repo[name]
          repo.update(
            name,
            attriibute.to_sym => value
          )
        else
          raise 'Not saved yet, sorry!'
        end
      end
    end

    def dump
      with_repo do |repo|
        if repo[name]
          repo.update(
            name,
            name: name,
            github_name: gh_alias,
            rubygems_name: rg_alias,
            reference: reference,
            meta_data: meta_to_json,
            agility_total_data: agility.total.to_json,
            agility_quarters_data: agility.quarters.to_json,
            community_total_data: community.total.to_json,
            community_quarters_data: community.quarters.to_json
          )
        else
          repo.create(
            name: name,
            github_name: gh_alias,
            rubygems_name: rg_alias,
            reference: reference,
            meta_data: meta_to_json,
            agility_total_data: agility.total.to_json,
            agility_quarters_data: agility.quarters.to_json,
            community_total_data: community.total.to_json,
            community_quarters_data: community.quarters.to_json
          )
        end
      end
    end

    def with_repo
      yield(self.class.repo)
    end

    module ClassMethods
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

      # TODO: Later we'll need pagination here!
      def load_all
        repo.all.map do |stored_prj|
          deserialize(stored_prj)
        end
      end

      def dump
        projects.each(&:dump)
      end

      private

      def deserialize(stored_project)
        Ossert::Project.new(
          stored_project.name,
          stored_project.github_name,
          stored_project.rubygems_name,
          stored_project.reference,
          ProjectRepo::Unpacker.process(stored_project)
        )
      end
    end
  end
end
