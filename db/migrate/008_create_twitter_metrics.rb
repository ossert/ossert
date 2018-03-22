# frozen_string_literal: true

Sequel.migration do
  up do
    METRIC_COLUMNS = %i[
      tweets_count favorites_count replies_count
      retweets_count coverage twitters_count
    ].freeze

    create_table(:twitter_metrics) do
      primary_key :id
      foreign_key :project_id, :projects, null: false, on_delete: :cascade
      Date :date, null: false

      METRIC_COLUMNS.each do |column_name|
        Float column_name, null: false
      end

      index %i[project_id date], unique: true
    end
  end

  down do
    drop_table(:twitter_metrics)
  end
end
