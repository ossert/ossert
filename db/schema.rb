migration = $rom_conf.gateways[:default].migration do
  change do
    # TODO: make schema.rb work with migrations along
    # create_table(:projects) do
    #   primary_key :id
    #   String :name, :null=>false
    #   String :github_name, :null=>false
    #   String :rubygems_name, :null=>false
    #   String :reference, :null=>false
    #   json :agility_total_data
    #   json :agility_quarters_data
    #   json :community_total_data
    #   json :community_quarters_data
    # end
  end
end

migration.apply($rom_conf.gateways[:default].connection, :up)
