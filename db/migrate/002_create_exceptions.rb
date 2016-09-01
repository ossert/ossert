Sequel.migration do
  up do
    create_table(:exceptions) do
      primary_key :id
      String :name, :null=>false
      String :github_name, :null=>false
    end
  end

  down do
    drop_table(:exceptions)
  end
end
