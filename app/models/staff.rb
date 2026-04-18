class Staff < ApplicationRecord
  has_secure_password

  belongs_to :hotel
  belongs_to :department, optional: true

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

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :department, presence: true, if: :staff?
  validate :department_belongs_to_hotel

  private

  def department_belongs_to_hotel
    return unless department
    return if department.hotel_id == hotel_id

    errors.add(:department, "must belong to the same hotel")
  end
end
