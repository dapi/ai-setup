FactoryBot.define do
  factory :department do
    association :hotel
    sequence(:name) { |n| "Department #{n}" }
  end
end
