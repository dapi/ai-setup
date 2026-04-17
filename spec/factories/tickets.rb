FactoryBot.define do
  factory :ticket do
    hotel
    guest { association :guest, hotel: hotel }
    department { association :department, hotel: hotel }
    staff { association :staff, hotel: hotel }
    subject { "Test subject" }
    body { "Test body" }
    status { :new }
    priority { :medium }
  end
end
