# frozen_string_literal: true

Sequel.migration do
  up do
    run 'ALTER TABLE projects ALTER COLUMN agility_total_data SET DATA TYPE jsonb USING agility_total_data::jsonb;'
    run 'ALTER TABLE projects ALTER COLUMN agility_quarters_data SET DATA TYPE jsonb USING agility_quarters_data::jsonb;'
    run 'ALTER TABLE projects ALTER COLUMN community_total_data SET DATA TYPE jsonb USING community_total_data::jsonb;'
    run 'ALTER TABLE projects ALTER COLUMN community_quarters_data SET DATA TYPE jsonb USING community_quarters_data::jsonb;'
    run 'ALTER TABLE projects ALTER COLUMN meta_data SET DATA TYPE jsonb USING meta_data::jsonb;'
  end
end
