class AddMessagesToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :messages, :json, default: []
  end
end
