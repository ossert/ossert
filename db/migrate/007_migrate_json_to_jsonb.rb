# frozen_string_literal: true

Sequel.migration do
  up do
    %w[agility_total_data
       agility_quarters_data
       community_total_data
       community_quarters_data
       meta_data].each do |column|
      run "ALTER TABLE projects ALTER COLUMN #{column} SET DATA TYPE jsonb USING #{column}::jsonb;"
    end
  end
end
