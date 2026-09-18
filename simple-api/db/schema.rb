ActiveRecord::Schema[8.1].define(version: 1) do
  # A minimal internal table makes the app's SQLite schema explicit for the
  # Roundhouse/Spinel runtime. The API does not expose or use this table.
  create_table 'api_runtime_states', force: :cascade do |t|
    t.string 'key', null: false
    t.string 'value'
  end
end
