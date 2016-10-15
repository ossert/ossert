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
