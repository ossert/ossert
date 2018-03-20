# frozen_string_literal: true

Sequel.migration do
  up do
    run 'ALTER TABLE projects ADD COLUMN created_at TIMESTAMP DEFAULT NOW() NOT NULL;'
    run 'ALTER TABLE projects ADD COLUMN updated_at TIMESTAMP DEFAULT NOW() NOT NULL;'
  end

  down do
    drop_column :projects, :created_at
    drop_column :projects, :updated_at
  end
end
