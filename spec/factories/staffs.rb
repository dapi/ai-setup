FactoryBot.define do
  factory :staff do
    association :hotel
    sequence(:name) { |n| "Staff Member #{n}" }
    sequence(:email) { |n| "staff#{n}@example.com" }
    password { "password" }
    role { :staff }

    trait :admin do
      role { :admin }
    end

    trait :manager do
      role { :manager }
    end
  end
end
