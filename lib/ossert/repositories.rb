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
end
