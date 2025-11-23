class ChangeRoutingToIntegerInQuestions < ActiveRecord::Migration[8.1]
  def change
    change_column :questions, :routing, :integer, using: 'routing::integer'
  end
end
