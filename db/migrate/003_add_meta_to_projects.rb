Sequel.migration do
  up do
    extension :pg_json

    alter_table(:projects) do
      add_column :meta_data, JSON
    end
  end

  down do
    drop_column :projects, :meta_data
  end
end
