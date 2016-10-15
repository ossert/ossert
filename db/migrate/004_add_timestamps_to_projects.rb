Sequel.migration do
  up do
    run "ALTER TABLE projects ADD COLUMN created_at TIMESTAMP DEFAULT NOW() NOT NULL;"
    run "ALTER TABLE projects ADD COLUMN updated_at TIMESTAMP DEFAULT NOW() NOT NULL;"
  end

  down do
    drop_column :projects, :meta_data
    drop_column :projects, :meta_data
  end
end
