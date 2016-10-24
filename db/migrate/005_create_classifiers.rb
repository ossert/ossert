Sequel.migration do
  up do
    extension :pg_json

    create_table(:classifiers) do
      primary_key :id
      String :section, :null=>false
      json :reference_values
    end

    run "ALTER TABLE classifiers ADD COLUMN created_at TIMESTAMP DEFAULT NOW() NOT NULL;"
    run "ALTER TABLE classifiers ADD COLUMN updated_at TIMESTAMP DEFAULT NOW() NOT NULL;"
  end

  down do
    drop_table(:classifiers)
  end
end
