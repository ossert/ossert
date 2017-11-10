# frozen_string_literal: true
Sequel.migration do
  up do
    extension :pg_json

    alter_table(:projects) do
      add_column :extra_data, :jsonb
    end
  end

  down do
    drop_column :projects, :extra_data
  end
end
