# frozen_string_literal: true
Sequel.migration do
  up do
    create_table(:aggregations) do
      primary_key :id
      String :name, null: false
      Integer :last_year_downloads
      Integer :last_year_participants
      Integer :last_year_contributors
      Integer :last_year_issues
    end
  end

  down do
    drop_table(:aggregations)
  end
end
