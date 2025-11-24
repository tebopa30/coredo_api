class ChangeDishIdNullableInSessions < ActiveRecord::Migration[8.1]
  def change
    change_column_null :sessions, :dish_id, true
  end
end
