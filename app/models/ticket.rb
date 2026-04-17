class Ticket < ApplicationRecord
  belongs_to :hotel
  belongs_to :guest
  belongs_to :department
  belongs_to :staff, optional: true

  validates :subject, presence: true
  validates :body, presence: true
  validate :associated_records_belong_to_hotel

  enum :status, {
    new: 0,
    in_progress: 1,
    done: 2,
    canceled: 3
  }, scopes: false

  enum :priority, {
    low: 0,
    medium: 1,
    high: 2
  }, scopes: false

  private

  def associated_records_belong_to_hotel
    return unless hotel

    validate_hotel_match(:guest, guest)
    validate_hotel_match(:department, department)
    validate_hotel_match(:staff, staff) if staff
  end

  def validate_hotel_match(association_name, record)
    return if record.blank? || record.hotel_id == hotel_id

    errors.add(association_name, "must belong to the same hotel as the ticket")
  end
end
