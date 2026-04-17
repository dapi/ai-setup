class AddHotelToTickets < ActiveRecord::Migration[7.1]
  def up
    add_reference :tickets, :hotel, foreign_key: true

    execute <<~SQL.squish
      UPDATE tickets
      SET hotel_id = guests.hotel_id
      FROM guests
      WHERE tickets.guest_id = guests.id
    SQL

    change_column_null :tickets, :hotel_id, false
  end

  def down
    remove_reference :tickets, :hotel, foreign_key: true
  end
end
