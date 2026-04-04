FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }

    trait :confirmed do
      confirmed_at { Time.current }
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :expired_confirmation do
      confirmed_at { nil }

      after(:create) do |user|
        user.update_columns(confirmation_sent_at: 25.hours.ago)
      end
    end
  end
end
