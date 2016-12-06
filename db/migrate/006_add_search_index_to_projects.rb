# frozen_string_literal: true
Sequel.migration do
  up do
    run 'CREATE EXTENSION pg_trgm'
    run 'CREATE INDEX projects_name_search_index ON projects USING gist (name gist_trgm_ops)'
  end

  down do
    run 'DROP INDEX projects_name_search_index'
    run 'DROP EXTENSION pg_trgm'
  end
end
