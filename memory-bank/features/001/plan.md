# Plan 001 — Secure admin hotel listing by role

**Ref:** spec.md  
**Branch:** `1-feature-001-secure-admin-hotel-listing-by-role`

---

## Step 1 — Uncomment `bcrypt` gem [BLOCKING]

**File:** `Gemfile`

Change line 37 from:

```ruby
# gem "bcrypt", "~> 3.1.7"
```

to:

```ruby
gem "bcrypt", "~> 3.1.7"
```

Then run:

```
bundle install
```

**Done when:** `bundle exec ruby -e "require 'bcrypt'"` exits with code 0.

> This step must complete successfully before any subsequent step. `has_secure_password` and `password_digest` are inoperable without bcrypt.

---

## Step 2 — Generate migration file

Run:

```
bin/rails generate migration AddPasswordDigestToStaffs password_digest:string
```

**Done when:** a new file `db/migrate/<timestamp>_add_password_digest_to_staffs.rb` exists.

---

## Step 3 — Add `null: false` constraint to migration

**File:** `db/migrate/<timestamp>_add_password_digest_to_staffs.rb`

Change the generated `add_column` line to:

```ruby
add_column :staffs, :password_digest, :string, null: false
```

**Done when:** the file contains `null: false` on the `password_digest` column.

---

## Step 4 — Run migration

> **Pre-condition:** PostgreSQL rejects `null: false` on `add_column` if the table already has rows.
> Check whether the dev `staffs` table has data: `Staff.count` in `bin/rails console`.
> If count > 0 — reset the database first:
> ```
> bin/rails db:reset
> ```
> If count == 0 — proceed directly.

```
bin/rails db:migrate
```

**Done when:** `bin/rails db:migrate:status` shows `up` for `AddPasswordDigestToStaffs`.

---

## Step 5 — Add `has_secure_password` to `Staff` model

**File:** `app/models/staff.rb`

Add `has_secure_password` on the line immediately after `class Staff < ApplicationRecord`.  
Do **not** add a manual `validates :password, presence: true` — `has_secure_password` provides it automatically.  
All existing associations and the `role` enum remain unchanged.

```ruby
class Staff < ApplicationRecord
  has_secure_password
  # ... existing code unchanged
end
```

**Done when:** `Staff.new.respond_to?(:authenticate)` returns `true` in `bin/rails console`.

---

## Step 6 — Create Staff factory

**File:** `spec/factories/staffs.rb` (new file)

```ruby
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
```

**Done when:** `spec/factories/staffs.rb` exists and defines `:staff` factory with `:admin` and `:manager` traits as shown above. Functional verification happens implicitly when step 11 passes.

> Factory must exist before steps 11–12 (request specs depend on it).

---

## Step 7 — Replace auth in `Admin::BaseController`

**File:** `app/controllers/admin/base_controller.rb`

1. **Remove** the existing `http_basic_authenticate_with` line.
2. **Add** `before_action :authenticate_staff!` in its place.
3. **Add** the following two private methods:

```ruby
private

def authenticate_staff!
  header = request.headers["Authorization"]

  unless header&.start_with?("Basic ")
    return http_401
  end

  decoded = Base64.strict_decode64(header.delete_prefix("Basic "))
  email, password = decoded.split(":", 2)
  @current_staff = Staff.find_by(email: email)&.authenticate(password)

  http_401 unless @current_staff
rescue ArgumentError
  http_401
end

def http_401
  response.headers["WWW-Authenticate"] = 'Basic realm="Admin"'
  render plain: "Unauthorized", status: :unauthorized
end
```

**Done when:** the file contains no reference to `http_basic_authenticate_with` and both `authenticate_staff!` and `http_401` are defined.

---

## Step 8 — Add role check to `Admin::HotelsController`

**File:** `app/controllers/admin/hotels_controller.rb`

1. **Add** `before_action :require_hotel_access!` as the first `before_action` in the class.
2. **Add** the following private method:

```ruby
private

def require_hotel_access!
  return if @current_staff.admin? || @current_staff.manager?

  render plain: "Forbidden", status: :forbidden
end
```

**Done when:** the file contains `before_action :require_hotel_access!` and the method is defined in the `private` section.

---

## Step 9 — Verify i18n keys for empty state [already present — verify only]

**Files:** `config/locales/en.yml`, `config/locales/ru.yml`

Both keys were added before this task. Confirm they are present and correct:

```yaml
# en.yml
en:
  admin:
    hotels:
      index:
        empty: "No hotels found."

# ru.yml
ru:
  admin:
    hotels:
      index:
        empty: "Отели не найдены."
```

**Done when:** `I18n.t("admin.hotels.index.empty")` returns `"No hotels found."` in `bin/rails console`. If the key is missing — add it; otherwise no change needed.

> Acceptance criterion is verified by **manual check only** — an automated integration test cannot reach the empty state because `Staff#hotel_id` is `NOT NULL`.

---

## Step 10 — Verify empty state in hotels index view [already present — verify only]

**File:** `app/views/admin/hotels/index.html.erb`

The empty-state branch was added before this task. Confirm the view contains an `if/else` that renders `t("admin.hotels.index.empty")` when there are no hotels:

```erb
<% if @hotels.empty? %>
  <tr>
    <td colspan="3"><%= t("admin.hotels.index.empty") %></td>
  </tr>
<% else %>
  ...
<% end %>
```

**Done when:** the view file contains a call to `t("admin.hotels.index.empty")` in the empty-state branch. If it is missing — add it; otherwise no change needed.

> Verified by **manual check only** — same constraint as step 9.

---

## Step 11 — Update `spec/requests/admin/access_spec.rb`

**File:** `spec/requests/admin/access_spec.rb`

Make two targeted changes:

1. Replace the existing `let!(:staff_member)` block (currently uses `Staff.create!` without a password) with:
   ```ruby
   let!(:staff_member) { create(:staff, :admin, hotel: hotel) }
   ```
   Keep `let!` (not `let`) to preserve eager-loading behaviour — `ticket` depends on `staff_member`.

2. Replace the existing `authorization_header` helper:
   ```ruby
   # before (rack key, hardcoded credentials)
   def authorization_header
     credentials = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "password")
     { "HTTP_AUTHORIZATION" => credentials }
   end

   # after (HTTP key, Staff-based credentials)
   def authorization_header
     encoded = Base64.strict_encode64("#{staff_member.email}:password")
     { "Authorization" => "Basic #{encoded}" }
   end
   ```

All three existing `describe` blocks and their assertions remain **unchanged**.

**Done when:** `bundle exec rspec spec/requests/admin/access_spec.rb` exits with 0 failures.

---

## Step 12 — Create `spec/requests/admin/hotels_spec.rb`

**File:** `spec/requests/admin/hotels_spec.rb` (new file)

Implement all eight scenarios:

| # | Scenario | Expected |
|---|----------|----------|
| 1 | No `Authorization` header | 401 + `WWW-Authenticate: Basic realm="Admin"` |
| 2 | `Authorization: Bearer sometoken` | 401 + `WWW-Authenticate` header |
| 3 | `Authorization: Basic !!!` (invalid base64) | 401 + `WWW-Authenticate` header |
| 4 | Valid base64, email not in DB | 401 |
| 5 | Valid email, wrong password | 401 |
| 6 | `admin` role, correct credentials | 200 + hotel name in body |
| 7 | `manager` role, correct credentials | 200 + hotel name in body |
| 8 | `staff` role, correct credentials | 403 |

Use the `auth_header(staff_record)` helper defined as:

```ruby
def auth_header(staff_record)
  encoded = Base64.strict_encode64("#{staff_record.email}:password")
  { "Authorization" => "Basic #{encoded}" }
end
```

**Done when:** `bundle exec rspec spec/requests/admin/hotels_spec.rb` exits with 0 failures, 8 examples.

---

## Step 13 — Run full test suite

```
bundle exec rspec
```

**Done when:** exit code is 0, all examples pass, output contains no failures or pending errors.

**Manual checks (outside the test suite):**
- `app/controllers/admin/base_controller.rb` contains no hardcoded `"admin"` or `"password"` strings.
- `Gemfile` contains `gem "bcrypt"` uncommented.
- Empty state view and i18n keys are confirmed by steps 9–10.

---

## Execution order and dependencies

```
Step 1 (bcrypt) ──► Step 2 (generate migration)
                         │
                    Step 3 (edit null: false)
                         │
                    Step 4 (run migration)
                         │
                    Step 5 (has_secure_password)
                         │
        ┌────────────────┼────────────────┬──────────────┐
   Step 6            Step 7           Step 8          Step 9
 (factory)      (BaseController) (HotelsController) (i18n keys)
        │            │                │               │
        └──────┬─────┘                │           Step 10
               │        ─────────────┘              (view)
          Step 11                                     │
    (update access_spec)                              │
               │                                     │
          Step 12                                     │
    (new hotels_spec)                                 │
               └──────────────────┬──────────────────┘
                              Step 13
                            (full suite)
```

Steps 6, 7, 8, 9 are all independent of each other and can be done in parallel after Step 5. Steps 9–10 feed into the manual checklist of step 13; steps 6–8 converge at step 11.
