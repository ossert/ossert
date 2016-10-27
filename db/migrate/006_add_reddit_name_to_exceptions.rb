Sequel.migration do
  up do
    alter_table(:exceptions) do
      add_column :reddit_name, String
    end
  end
  
  down do
    drop_column :exceptions, :reddit_name
  end
end