class AddStateToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :state, :jsonb, null: false, default: {}
  end
end
