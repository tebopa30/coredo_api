class AddCuisineAndHeavinessToDishes < ActiveRecord::Migration[8.1]
  def change
    add_column :dishes, :cuisine, :string
    add_column :dishes, :heaviness, :string
  end
end
