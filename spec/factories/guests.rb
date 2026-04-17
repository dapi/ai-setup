FactoryBot.define do
  factory :guest do
    association :hotel
    sequence(:name) { |n| "Guest #{n}" }
    sequence(:identifier_token) { |n| "guest-token-#{n}" }
    room_number { "101" }
  end
end
