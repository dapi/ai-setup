class AddSlugToHotels < ActiveRecord::Migration[7.1]
  class MigrationHotel < ApplicationRecord
    self.table_name = "hotels"
  end

  def up
    add_column :hotels, :slug, :string

    MigrationHotel.reset_column_information
    MigrationHotel.find_each do |hotel|
      hotel.update_columns(slug: "#{hotel.name.to_s.parameterize}-slug")
    end

    change_column_null :hotels, :slug, false
    add_index :hotels, :slug, unique: true
  end

  def down
    remove_index :hotels, :slug
    remove_column :hotels, :slug
  end
end
