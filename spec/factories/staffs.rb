FactoryBot.define do
  factory :staff do
    association :hotel
    sequence(:name) { |n| "Staff Member #{n}" }
    sequence(:email) { |n| "staff#{n}@example.com" }
    password { "password" }
    role { :staff }
    department { association(:department, hotel: hotel) if role.to_s == "staff" }

    trait :admin do
      role { :admin }
      department { nil }
    end

    trait :manager do
      role { :manager }
      department { nil }
    end
  end
end
