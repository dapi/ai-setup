class Staff < ApplicationRecord
  has_secure_password

  belongs_to :hotel

  has_many :assigned_tickets,
           class_name: "Ticket",
           foreign_key: :staff_id,
           inverse_of: :staff,
           dependent: :nullify

  enum :role, {
    admin: 0,
    manager: 1,
    staff: 2
  }, scopes: false
end
