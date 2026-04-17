# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Hotels
grand_palace = Hotel.find_or_create_by!(slug: "grand-palace-slug") do |h|
  h.name = "Grand Palace"
  h.timezone = "Europe/Moscow"
end

aurora = Hotel.find_or_create_by!(slug: "aurora-slug") do |h|
  h.name = "Aurora"
  h.timezone = "Europe/London"
end

# Departments
housekeeping_gp = Department.find_or_create_by!(hotel: grand_palace, name: "Housekeeping")
concierge_gp    = Department.find_or_create_by!(hotel: grand_palace, name: "Concierge")
restaurant_gp   = Department.find_or_create_by!(hotel: grand_palace, name: "Restaurant")

housekeeping_au = Department.find_or_create_by!(hotel: aurora, name: "Housekeeping")
concierge_au    = Department.find_or_create_by!(hotel: aurora, name: "Concierge")

# Staff
Staff.find_or_create_by!(email: "admin@grandpalace.com") do |s|
  s.hotel    = grand_palace
  s.name     = "Alice Admin"
  s.role     = :admin
  s.password = "password"
end

Staff.find_or_create_by!(email: "manager@grandpalace.com") do |s|
  s.hotel    = grand_palace
  s.name     = "Bob Manager"
  s.role     = :manager
  s.password = "password"
end

Staff.find_or_create_by!(email: "staff@grandpalace.com") do |s|
  s.hotel    = grand_palace
  s.name     = "Carol Staff"
  s.role     = :staff
  s.password = "password"
end

Staff.find_or_create_by!(email: "admin@aurora.com") do |s|
  s.hotel    = aurora
  s.name     = "Dan Admin"
  s.role     = :admin
  s.password = "password"
end

# Guests
alice = Guest.find_or_create_by!(identifier_token: "token-alice-001") do |g|
  g.hotel       = grand_palace
  g.name        = "Alice Guest"
  g.room_number = "101"
end

bob = Guest.find_or_create_by!(identifier_token: "token-bob-002") do |g|
  g.hotel       = grand_palace
  g.name        = "Bob Guest"
  g.room_number = "202"
end

charlie = Guest.find_or_create_by!(identifier_token: "token-charlie-003") do |g|
  g.hotel       = aurora
  g.name        = "Charlie Guest"
  g.room_number = "305"
end

# Knowledge base articles
KnowledgeBaseArticle.find_or_create_by!(hotel: grand_palace, title: "Check-in and Check-out Policy") do |a|
  a.content   = "Check-in starts at 14:00. Check-out is until 12:00. Early check-in and late check-out are available upon request."
  a.category  = "policies"
  a.published = true
end

KnowledgeBaseArticle.find_or_create_by!(hotel: grand_palace, title: "Restaurant Hours") do |a|
  a.content   = "Breakfast: 07:00–10:30. Lunch: 12:00–15:00. Dinner: 18:00–22:00."
  a.category  = "dining"
  a.published = true
end

KnowledgeBaseArticle.find_or_create_by!(hotel: grand_palace, title: "Pool and Spa Access") do |a|
  a.content   = "The pool is open daily from 08:00 to 22:00. Spa reservations required in advance."
  a.category  = "amenities"
  a.published = false
end

KnowledgeBaseArticle.find_or_create_by!(hotel: aurora, title: "Wi-Fi Instructions") do |a|
  a.content   = "Connect to network 'Aurora_Guest'. Password is provided at check-in."
  a.category  = "facilities"
  a.published = true
end

# Tickets
ticket1 = Ticket.find_or_create_by!(
  hotel: grand_palace,
  guest: alice,
  department: housekeeping_gp,
  status: :new,
  subject: "Extra towels",
  body: "Please bring extra towels to room 101."
) do |t|
  t.priority = :high
end

ticket2 = Ticket.find_or_create_by!(
  hotel: grand_palace,
  guest: bob,
  department: restaurant_gp,
  status: :in_progress,
  subject: "Room service order",
  body: "Please deliver dinner to room 202."
) do |t|
  t.priority = :medium
  t.staff    = Staff.find_by(email: "staff@grandpalace.com")
end

ticket3 = Ticket.find_or_create_by!(
  hotel: aurora,
  guest: charlie,
  department: concierge_au,
  status: :done,
  subject: "Taxi booking",
  body: "Please arrange a taxi to the airport for tomorrow morning."
) do |t|
  t.priority = :low
end

# Conversations and messages
conv1 = Conversation.find_or_create_by!(guest: alice, status: :open)

Message.find_or_create_by!(conversation: conv1, sender_type: "guest", content: "Hello, I need extra towels.")
Message.find_or_create_by!(conversation: conv1, sender_type: "staff", content: "Of course! We will send them right away.")

conv2 = Conversation.find_or_create_by!(guest: bob, status: :waiting_for_guest)

Message.find_or_create_by!(conversation: conv2, sender_type: "guest", content: "Can I get a late checkout?")
Message.find_or_create_by!(conversation: conv2, sender_type: "staff", content: "I checked availability — 14:00 is possible. Shall I confirm?")

conv3 = Conversation.find_or_create_by!(guest: charlie, status: :closed)

Message.find_or_create_by!(conversation: conv3, sender_type: "guest", content: "What time does breakfast start?")
Message.find_or_create_by!(conversation: conv3, sender_type: "staff", content: "Breakfast is served from 07:00 to 10:30.")
Message.find_or_create_by!(conversation: conv3, sender_type: "guest", content: "Thank you!")
