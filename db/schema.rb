require 'rom-sql'
require 'rom-repository'

conf = ROM::Configuration.new(:sql, ENV.fetch("DATABASE_URL"))

migration = conf.gateways[:default].migration do
  change do
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

migration.apply(conf.gateways[:default].connection, :up)
