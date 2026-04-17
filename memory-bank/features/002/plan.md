# Plan — Feature 002: Role-based authorization & Hotel CRUD

**Spec:** memory-bank/features/002/spec.md  
**Branch:** 3-feature-002-role-based-authorization-hotel-crud

## Current state

- `Admin::BaseController` — only `authenticate_staff!`, no `require_admin!`
- `Admin::HotelsController` — `require_hotel_access!` (admin + manager), only `index` action
- `Hotel` model — no `slug`, no validations, no `has_many :tickets`
- `Ticket` model — no `belongs_to :hotel`, no `subject`/`body` fields
- Routes — hotels `only: :index`, no nested resources
- Services — only example ping service, no `BaseService`/`Result`
- Factory `hotels.rb` — has `sequence(:name)`, no `slug`; no `tickets.rb` factory
- Views — only `hotels/index.html.erb` exists

---

## Layer 0 — Infrastructure: BaseService + Result

**Files to create:**
- `app/services/base_service.rb`
- `app/services/result.rb`

**Files to create (tests):**
- `spec/services/base_service_spec.rb` *(optional, skip if not required by spec)*

**Implementation note:**
- Do not rescue `Dry::Types::ConstraintError` / `Dry::Types::MissingKeyError` in `BaseService.call`
- The project currently uses `dry-initializer`, but does not expose `Dry::Types::*` constants; keep the base service contract minimal and explicit

**Checkpoint:** `bundle exec rspec spec/services/`

---

## Layer 1 — Authorization baseline

### `Admin::BaseController` (`app/controllers/admin/base_controller.rb`)
- Add `before_action :require_admin!` after `authenticate_staff!`
- Add private method `require_admin!` — `redirect_to root_path unless @current_staff.admin?`
- Keep `authenticate_staff!` unchanged, including `401` behavior for missing/invalid Basic Auth

### `Admin::HotelsController` (`app/controllers/admin/hotels_controller.rb`)
- Remove `require_hotel_access!` method and its `before_action`
- Keep `index` action unchanged in this layer

### Existing request specs to update before checkpoint
- `spec/requests/admin/hotels_spec.rb`
  - `"returns 200 with hotel name for manager role"` → expect `302` redirect to `root_path`
  - `"returns 403 for staff role"` → expect `302` redirect to `root_path`
- `spec/requests/admin/access_spec.rb`
  - Add manager/staff authorization cases for `GET /admin`, `GET /admin/staff`, `GET /admin/tickets`
  - Keep existing admin happy-path examples
  - Keep existing `401` example for unauthenticated `/admin`

**Checkpoint:** `bundle exec rspec spec/requests/`

---

## Layer 2 — Shared data/model prerequisites

> **Порядок внутри слоя обязателен**: сначала миграции, затем фабрики, затем модели, затем фиксы существующих спек, затем чекпойнт.

### Step 2.1 — Migrations

#### Migration 1: add `slug` to `hotels`
```
rails g migration AddSlugToHotels slug:string
```
- Safe rollout for non-empty DB:
  1. add column `slug` without `null: false`
  2. backfill existing rows with `"#{name.parameterize}-slug"`
  3. add `null: false`
  4. add unique index on `slug`

#### Migration 2: add unique index to `hotels.name`
```
rails g migration AddUniqueIndexToHotelsName
```
- Add unique index on `name`
- Required because the spec declares global uniqueness for `Hotel.name`, and critical constraints should be enforced at DB level

#### Migration 3: add `hotel_id` to `tickets`
```
rails g migration AddHotelToTickets hotel:references
```
- Safe rollout for non-empty DB:
  1. add reference without `null: false`
  2. backfill `tickets.hotel_id` from `ticket.guest.hotel_id`
  3. add `null: false`
  4. keep `foreign_key: true`

#### Migration 4: add `subject` and `body` to `tickets`
```
rails g migration AddSubjectAndBodyToTickets subject:string body:text
```
- Both `null: false, default: ""`

**Run:** `bin/rails db:migrate`

### Step 2.1.1 — Schema dump

- Commit updated `db/schema.rb` produced by migrations

### Step 2.2 — Factory updates

- `spec/factories/hotels.rb` — add `sequence(:slug) { |n| "hotel-#{n}-slug" }`
- `spec/factories/guests.rb` — create file:
  ```ruby
  FactoryBot.define do
    factory :guest do
      association :hotel
      sequence(:name) { |n| "Guest #{n}" }
      sequence(:identifier_token) { |n| "guest-token-#{n}" }
      room_number { "101" }
    end
  end
  ```
- `spec/factories/departments.rb` — create file:
  ```ruby
  FactoryBot.define do
    factory :department do
      association :hotel
      sequence(:name) { |n| "Department #{n}" }
    end
  end
  ```
- `spec/factories/tickets.rb` — create file:
  ```ruby
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
  ```

### Step 2.3 — Model changes

#### `Hotel` model (`app/models/hotel.rb`)
- Add validations: `name` (presence, uniqueness), `timezone` (presence), `slug` (presence, uniqueness, format `/\A[a-z0-9-]+\z/`)
- Add: `has_many :tickets, dependent: :restrict_with_exception`
- Add: `def to_param = slug` (required for `admin_hotel_path(hotel)` to use slug instead of id)
- Keep existing associations unchanged

#### `Ticket` model (`app/models/ticket.rb`)
- Add: `belongs_to :hotel`
- Add validations: `subject` (presence), `body` (presence)

### Step 2.4 — Fix existing spec: `spec/requests/admin/access_spec.rb`
- Replace `Ticket.create!(...)` with `create(:ticket, hotel: hotel, staff: staff_member, guest: guest, department: department, status: :in_progress, priority: :high)`
- The factory provides non-empty `subject` and `body` defaults, satisfying `presence: true` validations

### Step 2.5 — Update seeds (`db/seeds.rb`)
- Add `slug` when creating/finding hotels
- Add `hotel`, `subject`, and `body` when creating/finding tickets
- Keep seeds idempotent after the new required fields are introduced

**Checkpoint:** `bundle exec rspec` (ensure no regressions before CRUD slices)

---

## Layer 3 — Hotel CRUD (strict vertical slices)

### Shared prerequisites for all CRUD slices
- Create `app/services/admin/hotels/create_service.rb`
  - Slug is auto-generated from `name`: `slug = "#{params[:name].to_s.parameterize}-slug"`
  - Slug is immutable after creation — `UpdateService` does not touch it
- Create `app/services/admin/hotels/update_service.rb`
  - Permits only `name` and `timezone`; slug is never changed
- Create service specs:
  - `spec/services/admin/hotels/create_service_spec.rb`
  - `spec/services/admin/hotels/update_service_spec.rb`
- Update `app/views/layouts/admin.html.erb` to render `flash[:notice]` and `flash[:alert]`

**Checkpoint:** `bundle exec rspec spec/services/admin/hotels/`

### Slice 3.1 — `index`
- Route: keep existing `resources :hotels, only: :index` in `config/routes.rb`
- Controller: `Admin::HotelsController#index` unchanged
- View `app/views/admin/hotels/index.html.erb`
  - Keep hotel table and empty state with `t(".empty")`
- Rewrite only the `index` section in `spec/requests/admin/hotels_spec.rb`
  - Keep auth matrix for `GET /admin/hotels`
  - Cover non-empty and empty states

**Checkpoint:** `bundle exec rspec spec/requests/admin/hotels_spec.rb`

### Slice 3.2 — `show`
- Route: change `config/routes.rb` from `resources :hotels, only: :index` to `resources :hotels, only: %i[index show], param: :slug`
- Controller `app/controllers/admin/hotels_controller.rb`
  - Add `show`
  - Add `before_action :set_hotel, only: :show`
  - `set_hotel`: `@hotel = Hotel.find_by!(slug: params[:slug])`
  - In `set_hotel`, rescue `ActiveRecord::RecordNotFound` and `render plain: "Not Found", status: :not_found`
- Create `app/views/admin/hotels/show.html.erb`
- Show page renders hotel attributes only in this slice: `name`, `timezone`, `slug`
- Do not add nested-resource links yet; those routes are introduced in Layer 4
- Add i18n only for keys needed in this slice
- Extend `spec/requests/admin/hotels_spec.rb` with `show` cases only

**Checkpoint:** `bundle exec rspec spec/requests/admin/hotels_spec.rb`

### Slice 3.3 — `new` / `create`
- Route: extend `config/routes.rb` to `resources :hotels, only: %i[index show new create], param: :slug`
- Controller `app/controllers/admin/hotels_controller.rb`
  - Add `new`, `create`
  - Add `hotel_params` private method (permit: `name`, `timezone`; no `slug`)
  - `create` on success: `redirect_to admin_hotels_path, notice: "Hotel was successfully created."`
  - `create` on failure: `render :new, status: :unprocessable_entity`
- Create `app/views/shared/_errors.html.erb`
- Create `app/views/admin/hotels/new.html.erb` with form (fields: `name`, `timezone` via `time_zone_select`)
- Extend `spec/requests/admin/hotels_spec.rb` with `new/create` cases only

**Checkpoint:** `bundle exec rspec spec/requests/admin/hotels_spec.rb`

### Slice 3.4 — `edit` / `update`
- Route: extend `config/routes.rb` to `resources :hotels, only: %i[index show new create edit update], param: :slug`
- Controller `app/controllers/admin/hotels_controller.rb`
  - Add `edit`, `update`
  - Extend `before_action :set_hotel` to `%i[show edit update]`
  - `update` on success: `redirect_to admin_hotels_path, notice: "Hotel was successfully updated."`
  - `update` on failure: `render :edit, status: :unprocessable_entity`
- Create `app/views/admin/hotels/edit.html.erb` with form (fields: `name`, `timezone`; no `slug` field)
- Update `app/views/admin/hotels/index.html.erb` to add edit link now that `edit_admin_hotel_path` exists
- Add i18n: `index.edit_link` to `en.yml` and `ru.yml`
- Extend `spec/requests/admin/hotels_spec.rb` with `edit/update` cases only

**Checkpoint:** `bundle exec rspec spec/requests/admin/hotels_spec.rb`

### Slice 3.5 — `destroy`
- Route: extend `config/routes.rb` to full hotel CRUD: `resources :hotels, param: :slug`
- Controller `app/controllers/admin/hotels_controller.rb`
  - Add `destroy`
  - Extend `before_action :set_hotel` to `%i[show edit update destroy]`
  - On success: `redirect_to admin_hotels_path, notice: "Hotel was successfully deleted."`
  - On `rescue ActiveRecord::DeleteRestrictionError`: `redirect_to admin_hotels_path, alert: "Hotel has associated records and cannot be deleted."`
- Update `app/views/admin/hotels/index.html.erb` to add:
  - hotel name link to `admin_hotel_path(hotel)`
  - delete action via `button_to`, not `link_to ... method: :delete`, because the project does not currently load JS/Turbo helpers for method spoofing
- Add i18n key for destroy alert/notice only if the implementation chooses localized flash messages; otherwise keep literal English strings consistently in controller and specs
- Add i18n: `index.delete_link` and any `show.*` action-link keys actually used by the implementation
- Extend `spec/requests/admin/hotels_spec.rb` with `destroy` cases only

**Checkpoint:** `bundle exec rspec spec/requests/admin/hotels_spec.rb`

### After Slice 3.5 — finalize hotel request spec
- Ensure `spec/requests/admin/hotels_spec.rb` covers all cases from spec §9.1
- Do not postpone the full rewrite until the end; grow the file slice-by-slice so every checkpoint is meaningful

---

## Layer 4 — Nested resources

### Step 4.1 — Routes (`config/routes.rb`)
Extend existing hotel CRUD routes with nested resources:
```ruby
namespace :admin do
  root "hotels#index"

  resources :hotels, param: :slug do
    resources :staff, only: %i[index show], controller: "hotel_staff"
    resources :tickets, only: :index, controller: "hotel_tickets"
  end

  resources :staff, only: :index
  resources :tickets, only: :index
end
```

### Step 4.2 — `Admin::HotelStaffController` (`app/controllers/admin/hotel_staff_controller.rb`)
- New file: `index`, `show` actions
- `set_hotel`: `@hotel = Hotel.find_by!(slug: params[:hotel_slug])`
- In `set_hotel`, rescue `ActiveRecord::RecordNotFound` and `render plain: "Not Found", status: :not_found`
- `index`: `@staff = @hotel.staff.order(:name)`
- `show`: `@staff_member = @hotel.staff.find(params[:id])` so staff from another hotel returns `404`
- In `show`, rescue `ActiveRecord::RecordNotFound` and `render plain: "Not Found", status: :not_found`

### Step 4.3 — `Admin::HotelTicketsController` (`app/controllers/admin/hotel_tickets_controller.rb`)
- New file: `index` action
- `set_hotel`: `@hotel = Hotel.find_by!(slug: params[:hotel_slug])`
- In `set_hotel`, rescue `ActiveRecord::RecordNotFound` and `render plain: "Not Found", status: :not_found`
- `index`: `@tickets = @hotel.tickets.includes(:guest, :department, :staff).order(created_at: :desc)`

### Step 4.4 — Views
- `app/views/admin/hotel_staff/index.html.erb` — list staff (name, email, role) + empty state
- `app/views/admin/hotel_staff/show.html.erb` — staff detail (name, email, role, hotel.name)
- `app/views/admin/hotel_tickets/index.html.erb` — tickets list (subject, body, status, priority, guest.name, department.name, staff.name or unassigned) + empty state
- Update `app/views/admin/hotels/show.html.erb` to add now-valid links:
  - `staff_link` → `admin_hotel_staff_index_path(@hotel)`
  - `tickets_link` → `admin_hotel_tickets_path(@hotel)`
  - Optional `edit`/`delete` actions only if they are rendered on show page in the implementation

### Step 4.5 — i18n additions (`en.yml` + `ru.yml`)
- `hotel_staff.index.empty`
- `hotel_tickets.index.empty`
- `hotel_tickets.index.unassigned`
- `hotels.show.staff_link`
- `hotels.show.tickets_link`
- Any remaining `hotels.show.*` action-link keys actually used by the implementation

### Step 4.6 — Request specs
- `spec/requests/admin/hotel_staff_spec.rb` — cases from spec §9.2, including `manager -> 302`, `staff -> 302`, `no auth -> 401`
- `spec/requests/admin/hotel_tickets_spec.rb` — cases from spec §9.3, including `manager -> 302`, `staff -> 302`, `no auth -> 401`

**Checkpoint:** `bundle exec rspec spec/requests/admin/hotel_staff_spec.rb spec/requests/admin/hotel_tickets_spec.rb`

---

## Final checkpoint

```bash
bundle exec rspec
```

Expected: 0 failures, all existing tests pass.

---

## File inventory

| Action   | File                                                          |
|----------|---------------------------------------------------------------|
| Create   | `app/services/base_service.rb`                               |
| Create   | `app/services/result.rb`                                     |
| Create   | `app/services/admin/hotels/create_service.rb`                |
| Create   | `app/services/admin/hotels/update_service.rb`                |
| Create   | `db/migrate/*_add_slug_to_hotels.rb`                         |
| Create   | `db/migrate/*_add_unique_index_to_hotels_name.rb`            |
| Create   | `db/migrate/*_add_hotel_to_tickets.rb`                       |
| Create   | `db/migrate/*_add_subject_and_body_to_tickets.rb`            |
| Modify   | `db/schema.rb`                                              |
| Modify   | `db/seeds.rb`                                               |
| Modify   | `app/models/hotel.rb`                                        |
| Modify   | `app/models/ticket.rb`                                       |
| Modify   | `app/controllers/admin/base_controller.rb`                   |
| Modify   | `app/controllers/admin/hotels_controller.rb`                 |
| Create   | `app/controllers/admin/hotel_staff_controller.rb`            |
| Create   | `app/controllers/admin/hotel_tickets_controller.rb`          |
| Modify   | `config/routes.rb`                                           |
| Modify   | `app/views/layouts/admin.html.erb`                           |
| Modify   | `app/views/admin/hotels/index.html.erb`                      |
| Create   | `app/views/admin/hotels/show.html.erb`                       |
| Create   | `app/views/admin/hotels/new.html.erb`                        |
| Create   | `app/views/admin/hotels/edit.html.erb`                       |
| Create   | `app/views/shared/_errors.html.erb`                          |
| Create   | `app/views/admin/hotel_staff/index.html.erb`                 |
| Create   | `app/views/admin/hotel_staff/show.html.erb`                  |
| Create   | `app/views/admin/hotel_tickets/index.html.erb`               |
| Modify   | `config/locales/en.yml`                                      |
| Modify   | `config/locales/ru.yml`                                      |
| Modify   | `spec/factories/hotels.rb`                                   |
| Create   | `spec/factories/guests.rb`                                   |
| Create   | `spec/factories/departments.rb`                              |
| Create   | `spec/factories/tickets.rb`                                  |
| Modify   | `spec/requests/admin/hotels_spec.rb`                         |
| Modify   | `spec/requests/admin/access_spec.rb`                         |
| Create   | `spec/requests/admin/hotel_staff_spec.rb`                    |
| Create   | `spec/requests/admin/hotel_tickets_spec.rb`                  |
| Create   | `spec/services/admin/hotels/create_service_spec.rb`          |
| Create   | `spec/services/admin/hotels/update_service_spec.rb`          |
