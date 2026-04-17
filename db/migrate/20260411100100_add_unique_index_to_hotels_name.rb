class AddUniqueIndexToHotelsName < ActiveRecord::Migration[7.1]
  def change
    add_index :hotels, :name, unique: true
  end
end
