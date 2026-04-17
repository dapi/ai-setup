FactoryBot.define do
  factory :hotel do
    sequence(:name) { |n| "Hotel #{n}" }
    sequence(:slug) { |n| "hotel-#{n}-slug" }
    timezone { "UTC" }
  end
end
