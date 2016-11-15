# frozen_string_literal: true
module Ossert
  module Saveable
    UNUSED_REFERENCE = 'unused'
    ATTRIBUTE_EXTRACT_VALUE_MAP = {
      agility_total_data: ->(project) { project.agility.total.to_json },
      agility_quarters_data: ->(project) { project.agility.quarters.to_json },
      community_total_data: ->(project) { project.community.total.to_json },
      community_quarters_data: ->(project) { project.community.quarters.to_json },
      meta_data: ->(project) { project.meta_to_json }
    }.freeze

    def self.included(base)
      base.extend(ClassMethods)
    end

    def dump_attribute(attriibute)
      attriibute = attriibute.to_sym
      value = ATTRIBUTE_EXTRACT_VALUE_MAP.fetch(attriibute).call(self)

      raise 'Not saved yet, sorry!' unless (found_project = ::Project.find(name: name))
      found_project.update(name, attriibute => value, updated_at: Time.now.utc)
      nil
    end

    def dump
      validate!
      if (found_project = ::Project.find(name: name))
        found_project.update(attributes.merge(updated_at: Time.now.utc))
      else
        ::Project.create(attributes)
      end
      nil
    end

    def valid?
      [name, github_alias, rubygems_alias].all?(&:present?)
    end

    class RecordInvalid < StandardError
      attr_reader :message
      def initialize(*)
        super
        @message = "Couldn't save project. Validation failed!"
      end
    end

    def validate!
      raise RecordInvalid.new unless valid?
    end

    def attributes
      meta_attributes.merge(data_attributes)
    end

    def meta_attributes
      {
        name: name,
        github_name: github_alias,
        rubygems_name: rubygems_alias,
        reference: reference
      }
    end

    def data_attributes
      {
        meta_data: meta_to_json,
        agility_total_data: agility.total.to_json,
        agility_quarters_data: agility.quarters.to_json,
        community_total_data: community.total.to_json,
        community_quarters_data: community.quarters.to_json
      }
    end

    def without_github_data?
      github_alias == NO_GITHUB_NAME
    end

    module ClassMethods
      def exist?(name)
        ::Project.filter(name: name).get(:name).present?
      end

      def random_top(count = 10)
        ::Project.where(reference: %w(ClassA ClassB ClassC)).random(count)
      end

      def random(count = 10)
        ::Project.dataset.random(count)
      end

      def find_by_name(name, reference = Ossert::Saveable::UNUSED_REFERENCE)
        if (name_exception = ::NameException.find(name: name))
          new(name, name_exception.github_name, name, reference)
        else
          new(name, nil, name, reference)
        end
      end

      def load_by_name(name)
        stored_prj = ::Project.find(name: name)
        deserialize(stored_prj) if stored_prj
      end

      def load_referenced
        ::Project.referenced.map do |stored_prj|
          deserialize(stored_prj)
        end
      end

      def load_later_than(id)
        ::Project.later_than(id).map do |stored_prj|
          deserialize(stored_prj)
        end
      end

      def cleanup_referencies!
        ::Project.dataset.update(reference: UNUSED_REFERENCE)
      end

      def load_all
        ::Project.paged_each.map do |stored_prj|
          deserialize(stored_prj)
        end
      end

      def yield_all
        ::Project.paged_each do |stored_prj|
          yield deserialize(stored_prj)
        end
      end

      def dump
        projects.each(&:dump)
      end

      private

      def deserialize(stored_project)
        project = Ossert::Project.new(
          stored_project.name,
          stored_project.github_name,
          stored_project.rubygems_name,
          stored_project.reference
        )
        project.assign_data(
          ::Project::Unpacker.process(stored_project)
        )
        project
      end
    end
  end
end
