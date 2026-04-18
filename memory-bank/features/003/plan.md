# План — Feature 003: staff ticket workflow без admin

**Spec:** memory-bank/features/003/spec.md

## Текущее состояние

- `Admin::BaseController` уже использует HTTP Basic authentication через `Staff` с realm `Admin` и требует роль `admin`.
- `/admin/**` изолирован в `namespace :admin`; namespace `/operations/**` пока отсутствует.
- `BaseService` и `Result` уже существуют, их нужно переиспользовать для operations services.
- `Staff` уже имеет `has_secure_password`, `belongs_to :hotel`, enum ролей `admin: 0, manager: 1, staff: 2` и association назначенных тикетов.
- `Staff` пока не имеет `department_id`, association с department, uniqueness validation для email и department-инвариантов по роли.
- `Ticket` уже принадлежит `hotel`, `guest`, `department` и optional `staff`; существующие статусы: `new`, `in_progress`, `done`, `canceled`.
- Фабрики для hotels, departments, guests, staffs и tickets уже есть, но фабрика `:staff` пока не назначает department.

---

## Layer 0 — Данные и инварианты

> Этот слой блокирует все operations slices, потому что staff visibility и staff creation зависят от `staffs.department_id`.

### Step 0.0 — Проверить существующие данные перед constraint-ами

Выполнить preflight в той среде, где будет запускаться migration:

```bash
bin/rails runner 'puts Staff.group(:email).having("COUNT(*) > 1").count'
bin/rails runner 'puts Staff.column_names.include?("department_id") ? Staff.where(role: Staff.roles[:staff]).where(department_id: nil).count : Staff.where(role: Staff.roles[:staff]).count'
```

Проверить:

- нет duplicate `staffs.email`, иначе Step 0.1 упадет на unique index и требуется отдельное решение по данным
- если `department_id` еще отсутствует, количество существующих rows с role `staff` известно; Step 0.1 должен backfill-ить их до добавления check constraint
- если migration уже частично применялась, количество `staff` rows без department известно; Step 0.1 должен backfill-ить их до добавления check constraint

Если duplicate emails найдены, остановить реализацию Layer 0 и не добавлять unique index до отдельного решения по данным. План этой фичи не должен молча выбирать, какую учетную запись сохранять или как объединять пользователей.

**Готово, когда:** понятно, что Step 0.1 не сломается на существующих duplicate emails, а существующие role `staff` rows покрыты migration backfill.

### Step 0.1 — Добавить non-destructive migration для staff department

Создать новую migration, не изменяя существующие migrations:

```bash
bin/rails generate migration AddDepartmentToStaffs department:references
```

> **Важно:** сгенерированная команда создаёт `null: false` по умолчанию. Необходимо вручную изменить на `null: true` — иначе migration упадёт на существующих rows без department.

Отредактировать migration так, чтобы она выполняла только эти безопасные изменения:

- `add_reference :staffs, :department, null: true, foreign_key: true`
- `add_index :staffs, :email, unique: true`
- backfill для существующих `staffs.role = 2`: назначить department из того же hotel до добавления check constraint; использовать первый department по `id`, а если у hotel нет departments, создать для него fallback department `General` с заполненными `created_at` и `updated_at`
- `add_check_constraint :staffs, "role != 2 OR department_id IS NOT NULL", name: "staff_role_requires_department"`

Backfill писать внутри migration через SQL/anonymous AR classes, а не через runtime `Staff` model, потому что Step 0.3 позже меняет validations.
Если используются anonymous AR classes, после `add_reference` явно вызвать `reset_column_information` для staff-класса перед backfill.

**Готово, когда:** migration создана, не удаляет данные, не меняет существующие migration-файлы и применима к базе, где уже есть role `staff` users без department.

### Step 0.2 — Запустить migration и обновить schema

Выполнить:

```bash
bin/rails db:migrate
```

**Готово, когда:** `db/schema.rb` содержит `staffs.department_id`, unique index на `staffs.email`, foreign key на departments и check constraint `staff_role_requires_department`.

### Step 0.3 — Обновить factories для валидных staff users

> Factories обновляются до добавления model validations (Step 0.6), потому что DB check constraint
> из Step 0.1 применяется к test DB при первом запуске rspec после миграции. Если factory остается
> со старым контрактом, существующие тесты упадут сразу после Step 0.2.

**Файл:** `spec/factories/staffs.rb`

Изменить default factory `:staff` так, чтобы records с ролью `:staff` получали department из того же hotel:

- оставить `association :hotel`
- добавить conditional department assignment для role `staff`, например через transient/after-build или `department { association(:department, hotel: hotel) if role.to_s == "staff" }`
- в traits `:admin` и `:manager` явно сбрасывать `department { nil }`, чтобы `create(:staff, :manager)` и `create(:staff, :admin)` проверяли роли без department

**Готово, когда:** `create(:staff)` создает валидного operational staff user, а `create(:staff, :manager)` и `create(:staff, :admin)` остаются валидными.

### Step 0.4 — Обновить ticket factory под новый staff invariant

**Файл:** `spec/factories/tickets.rb`

Проверить и при необходимости изменить `staff` association так, чтобы assigned staff всегда был из того же hotel и department не нарушал новый invariant:

- `staff { association(:staff, hotel: hotel) }` допустим, если `spec/factories/staffs.rb` назначает department из того же hotel
- не создавать staff без department для default ticket factory

**Готово, когда:** `create(:ticket)` остается валидным после добавления `Staff` validations и DB check constraint.

### Step 0.5 — Обновить seed data под новый staff invariant

**Файл:** `db/seeds.rb`

Изменить seed для `staff@grandpalace.com` так, чтобы seeded staff user с role `:staff` всегда получал department из своего hotel, например `housekeeping_gp`.

Сделать seed idempotent для уже существующей записи:

- использовать переменную для seeded staff user вместо fire-and-forget `Staff.find_or_create_by!`
- выставлять `department = housekeeping_gp`, если department отсутствует
- сохранять запись после assignment

Не назначать department seeded `admin` или `manager` users.

**Готово, когда:** `bin/rails db:seed` проходит на fresh DB после Step 0.6 validations и не оставляет seeded role `staff` без department.

### Step 0.6 — Обновить инварианты модели `Staff`

**Файл:** `app/models/staff.rb`

Добавить:

- `belongs_to :department, optional: true`
- validation presence для `name`
- validation presence и uniqueness для `email`
- validation presence для `department`, когда `staff?`
- validation, что `department.hotel_id == hotel_id`, когда department присутствует

Не добавлять workflow/business logic в модель.

**Готово, когда:** validations модели выражают только инварианты из section 5 spec.

### Checkpoint Layer 0

```bash
bundle exec rspec
```

Все существующие тесты должны проходить. Если есть failures — исправить до перехода к Layer 1.

---

## Layer 1 — Operations namespace, authentication и authorization shell

### Step 1.1 — Добавить operations routes

**Файл:** `config/routes.rb`

Добавить новый namespace, не меняя admin routes:

```ruby
namespace :operations do
  root "home#index"

  resources :staff, only: %i[index new create]
  resources :tickets, only: %i[index show edit update] do
    member do
      patch :start
      patch :complete
    end
  end
end
```

**Готово, когда:** `bin/rails routes -g operations` показывает `/operations`, `/operations/staff`, `/operations/tickets`, `/operations/tickets/:id/start` и `/operations/tickets/:id/complete`; `/admin/**` routes не требуют изменений. Controller behavior проверяется после Steps 1.3-1.5.
Ожидаемые helpers для staff routes из-за `resources :staff`: `operations_staff_index_path` для index/create и `new_operations_staff_path` для new.

### Step 1.2 — Создать operations layout

**Создать файл:** `app/views/layouts/operations.html.erb`

Обязанности layout:

- выводить flash notice/alert
- выводить tickets navigation для manager и staff
- выводить staff navigation только при `@current_staff.manager?`
- делать `yield` основного контента

Navigation links должны быть обычными server-rendered links.

**Готово, когда:** все operations controllers могут использовать `layout "operations"`.

### Step 1.3 — Создать `Operations::BaseController`

**Создать файл:** `app/controllers/operations/base_controller.rb`

Реализовать:

- `before_action :authenticate_staff!`
- `layout "operations"`
- `rescue_from ActiveRecord::RecordNotFound, with: :not_found`
- HTTP Basic authentication с тем же credential lookup, что в `Admin::BaseController`
- `WWW-Authenticate: Basic realm="Operations"` для отсутствующих, malformed или невалидных credentials
- сохранение authenticated user в `@current_staff`
- запрет для `admin` users через `403 Forbidden`
- `helper_method :current_staff`, чтобы layout и views могли безопасно проверять роль текущего operations user
- helper/private methods:
  - `current_staff` — возвращает `@current_staff`
  - `require_manager!` — разрешает только role `manager`; для `staff` рендерит `403`
  - `require_staff!` — разрешает только role `staff`; для `manager` рендерит `403`
  - `http_unauthorized` — выставляет `WWW-Authenticate: Basic realm="Operations"` и рендерит `401`
  - `forbidden` — рендерит `403 Forbidden`
  - `not_found` — рендерит `404 Not Found`
  - `current_hotel` — возвращает `@current_staff.hotel`

**Готово, когда:** missing/invalid credentials возвращают `401` с operations realm, admin credentials возвращают `403`, manager credentials проходят authentication, staff credentials проходят authentication; `require_manager!` возвращает `403` для staff, `require_staff!` возвращает `403` для manager.

### Step 1.4 — Создать authenticated operations root redirect

**Создать файл:** `app/controllers/operations/home_controller.rb`

Реализовать:

- `Operations::HomeController` наследуется от `Operations::BaseController`
- action `index` делает `redirect_to operations_tickets_path`

Не использовать route-level `redirect`, потому что он обойдет `Operations::BaseController` и не проверит Basic Auth.

**Готово, когда:** authenticated manager/staff запрос к `/operations` получает redirect на `/operations/tickets`, no credentials получают `401`, admin получает `403`.

### Step 1.5 — Добавить request specs для authentication и role matrix

**Создать файлы:**

- `spec/requests/operations/authentication_spec.rb`
- `spec/requests/operations/access_spec.rb`

На этом слое проверить только endpoints, которые уже могут существовать без ticket/staff controllers:

- no credentials на `/operations` -> `401`
- invalid credentials -> `401`
- malformed Basic header -> `401`
- `WWW-Authenticate` header равен `Basic realm="Operations"`
- admin credentials на `/operations` -> `403`
- manager credentials на `/operations` -> redirect на `/operations/tickets`
- staff credentials на `/operations` -> redirect на `/operations/tickets`

Остальные role/action matrix checks добавить в request specs соответствующих slices:

- Step 3.3: admin получает `403` для representative staff-management routes
- Step 3.3: manager может открывать staff-management routes, staff получает `403`
- Step 4.3: admin получает `403` для representative ticket read routes
- Step 5.4: admin получает `403` для representative ticket edit/update routes
- Step 5.4: staff не может открывать manager edit/update routes
- Step 6.2: staff может открывать ticket index/show routes, когда есть visible ticket setup
- Step 7.3: admin получает `403` для representative transition routes

**Checkpoint:**

```bash
bundle exec rspec spec/requests/operations/authentication_spec.rb spec/requests/operations/access_spec.rb
```

---

## Layer 2 — База service/query objects

> Service/query objects создаются до подключения controllers, чтобы controllers с первого slice оставались thin.

Все operations command services должны:

- наследоваться от `BaseService`
- объявлять dependencies как `option`
- иметь один public instance method `call`
- возвращать `Result` через `success`/`failure`

Operations query object должен:

- объявлять dependencies как `option` через `extend Dry::Initializer` или наследование от `BaseService`
- иметь один public instance method `call`
- возвращать `ActiveRecord::Relation`, а не `Result`

### Step 2.1 — Создать `Operations::Tickets::VisibleTicketsQuery`

**Создать файл:** `app/services/operations/tickets/visible_tickets_query.rb`

Контракт:

- option: `staff`
- один public method: `call`
- manager: вернуть все tickets для `staff.hotel`
- staff: вернуть tickets для `staff.hotel`, где `staff_id == staff.id OR department_id == staff.department_id`
- admin: вернуть `Ticket.none`
- include associations, нужные views: `department`, `staff`
- deterministic ordering, предпочтительно newest first

**Создать spec:** `spec/services/operations/tickets/visible_tickets_query_spec.rb`

Покрыть manager visibility, assigned staff visibility, same-department visibility, unrelated department exclusion и cross-hotel exclusion.

### Step 2.2 — Создать `Operations::Staff::CreateService`

**Создать файл:** `app/services/operations/staff/create_service.rb`

Контракт:

- options: `manager`, `params`
- один public method: `call`
- whitelist только `name`, `email`, `password`, `password_confirmation`, `department_id`
- принудительно выставлять `hotel: manager.hotel`
- принудительно выставлять `role: :staff`
- отклонять cross-hotel departments
- возвращать `success(result: staff)` или `failure(error_code:, messages:, result: staff)`
- не принимать role или hotel из params
- внутри namespace `Operations::Staff` обращаться к ActiveRecord-модели как `::Staff`, чтобы не спутать ее с модулем `Operations::Staff`

**Создать spec:** `spec/services/operations/staff/create_service_spec.rb`

Покрыть успешное создание, forced hotel, forced role, duplicate email, cross-hotel department denial, missing department, что role `staff` требует department, и ignored unpermitted attributes.

### Step 2.3 — Создать `Operations::Tickets::ManagerUpdateService`

**Создать файл:** `app/services/operations/tickets/manager_update_service.rb`

Контракт:

- options: `manager`, `ticket`, `params`
- один public method: `call`
- требовать `ticket.hotel_id == manager.hotel_id`
- whitelist только `staff_id` и `status`
- поддерживать partial update: если `staff_id` или `status` отсутствует в params, соответствующий текущий атрибут ticket не меняется
- разрешать blank `staff_id` для unassign
- отклонять cross-hotel assignees
- отклонять assignees, у которых role не `staff`
- принимать только существующие ticket enum statuses
- invalid `status` возвращает failure result, а не пробрасывает `ArgumentError` из enum assignment
- никогда не менять `guest_id`, `hotel_id`, `department_id`, `subject`, `body` или `priority`

**Создать spec:** `spec/services/operations/tickets/manager_update_service_spec.rb`

Покрыть assignment, reassignment, unassignment, status update, cross-hotel staff denial, non-staff assignee denial, что assignee должен быть role `staff` и принадлежать тому же hotel, invalid status, cross-hotel ticket denial и ignored disallowed attributes.

### Step 2.4 — Создать staff transition services

**Создать файлы:**

- `app/services/operations/tickets/start_service.rb`
- `app/services/operations/tickets/complete_service.rb`

Общий контракт:

- options: `staff`, `ticket`
- один public method: `call`
- требовать role `staff`
- требовать same hotel
- требовать personal assignment
- возвращать `Result`

`StartService`:

- разрешать только `new` -> `in_progress`

`CompleteService`:

- разрешать только `in_progress` -> `done`

**Создать specs:**

- `spec/services/operations/tickets/start_service_spec.rb`
- `spec/services/operations/tickets/complete_service_spec.rb`

Покрыть valid transitions, unassigned ticket denial, same-department but unassigned denial, cross-hotel denial, non-staff actor denial и invalid transition denial.

**Checkpoint:**

```bash
bundle exec rspec spec/services/operations
```

---

## Layer 3 — Slice 1: Manager создает staff

### Step 3.1 — Создать operations staff controller

**Создать файл:** `app/controllers/operations/staff_controller.rb`

Actions:

- `index`: только manager, список same-hotel staff users с role `staff`, include department, order by name/email
- `new`: только manager, подготовить unsaved staff object и `@departments = current_hotel.departments.order(:name)`
- `create`: только manager, вызвать `Operations::Staff::CreateService`; при failure заново подготовить `@departments = current_hotel.departments.order(:name)`
- если controller/view нужен unsaved staff object, создавать его через `::Staff.new`, потому что `Operations::Staff` уже используется как service namespace

Authorization order:

- `require_manager!` должен выполняться до query/build/service call, чтобы `staff` и `admin` не могли получить данные staff-management routes

Response behavior:

- successful create redirect на `/operations/staff` с flash `Staff created`
- validation failure render `new`, status `422`, и expose `@result`
- staff role получает `403` для всех routes этого controller

### Step 3.2 — Создать staff views

**Создать файлы:**

- `app/views/operations/staff/index.html.erb`
- `app/views/operations/staff/new.html.erb`
- `app/views/operations/staff/_form.html.erb`

Требования к views:

- index table columns: `name`, `email`, `department`
- empty state: `No staff found`
- form fields только для whitelisted params: `name`, `email`, `password`, `password_confirmation`, `department_id`
- form отправляется на `operations_staff_index_path`
- department select содержит только departments из manager hotel
- validation summary выводит `@result.messages`, когда create action рендерит `new` со статусом `422`
- не выводить fields для role или hotel

### Step 3.3 — Добавить request specs для staff create

**Создать файл:** `spec/requests/operations/staff_spec.rb`

Покрыть:

- manager staff index non-empty и empty states
- manager new page содержит только same-hotel departments
- manager создает staff с same-hotel department
- create success redirect на `/operations/staff` и flash `Staff created`
- validation failure возвращает `422`
- cross-hotel department denial возвращает `422`
- admin user получает `403` для representative index/new/create requests
- staff user получает `403` для index/new/create
- params не могут выставить `role` или `hotel_id`

**Checkpoint:**

```bash
bundle exec rspec spec/services/operations/staff/create_service_spec.rb spec/requests/operations/staff_spec.rb
```

---

## Layer 4 — Slice 2: Manager смотрит список и карточку tickets

### Step 4.1 — Создать read actions в operations tickets controller

**Создать файл:** `app/controllers/operations/tickets_controller.rb`

Сначала реализовать только:

- `index`
- `show`

Controller behavior:

- использовать `Operations::Tickets::VisibleTicketsQuery` для `index`
- scope `show` lookup через `current_hotel.tickets`
- на этом slice разрешить `index`/`show` только manager через `require_manager!`; staff read access подключается отдельно в Layer 6
- cross-hotel records возвращают `404`
- запрещенные role/action combinations возвращают `403`

### Step 4.2 — Создать ticket list/show views

**Создать файлы:**

- `app/views/operations/tickets/index.html.erb`
- `app/views/operations/tickets/show.html.erb`

Index requirements:

- table columns: `id`, `status`, `department`, `staff`
- empty state: `No tickets found`
- manager rows link на show и могут показывать edit link только после подключения edit route в Layer 5
- view должен оставаться role-neutral для будущего staff read access: rows link на show без manager-only assumptions

Show requirements:

- выводить ticket id, status, department, staff, subject, body, priority
- выводить manager edit link только для manager после подключения edit route
- не выводить start/complete buttons до Step 7.2, потому что transition actions еще не реализованы

### Step 4.3 — Добавить manager ticket read request specs

**Создать файл:** `spec/requests/operations/tickets_manager_spec.rb`

Покрыть:

- manager видит все same-hotel tickets
- manager не видит cross-hotel tickets
- manager может открыть same-hotel ticket show
- manager opening cross-hotel ticket возвращает `404`
- admin получает `403` для representative index/show requests
- index empty state

**Checkpoint:**

```bash
bundle exec rspec spec/services/operations/tickets/visible_tickets_query_spec.rb spec/requests/operations/tickets_manager_spec.rb
```

---

## Layer 5 — Slice 3: Manager назначает и обновляет tickets

### Step 5.1 — Добавить manager edit/update actions

**Файл:** `app/controllers/operations/tickets_controller.rb`

Добавить:

- `edit`: только manager, только same-hotel ticket, подготовить `@assignees = current_hotel.staff.where(role: :staff).includes(:department).order(:name, :email)` и `@statuses = Ticket.statuses.keys`
- `update`: только manager, только same-hotel ticket, вызвать `Operations::Tickets::ManagerUpdateService`; при failure заново подготовить `@assignees` и `@statuses`

Authorization order:

- `require_manager!` должен выполняться до ticket lookup, чтобы `staff` и `admin` получали `403` для manager-only actions независимо от `ticket_id`

Response behavior:

- success redirect на `/operations/tickets/:id` с flash `Ticket updated`
- validation failure render `edit`, status `422`, и expose `@result`
- cross-hotel ticket lookup возвращает `404`
- staff role получает `403`

### Step 5.2 — Создать manager ticket edit view

**Создать файл:** `app/views/operations/tickets/edit.html.erb`

Требования к view:

- fields только для `staff_id` и `status`
- assignment select содержит только users с `role: :staff` из manager hotel
- blank staff option разрешает unassignment
- status select содержит только существующие enum statuses
- validation summary выводит `@result.messages`, когда update action рендерит `edit` со статусом `422`
- нет fields для guest, hotel, department, subject, body или priority

### Step 5.3 — Обновить manager controls в ticket index/show

**Файлы:**

- `app/views/operations/tickets/index.html.erb`
- `app/views/operations/tickets/show.html.erb`

Добавить manager-only edit links после реализации edit/update.

### Step 5.4 — Добавить manager update request specs

**Файл:** `spec/requests/operations/tickets_manager_spec.rb`

Расширить проверками:

- edit page выводит только same-hotel staff assignees
- assignment
- reassignment
- unassignment
- status update
- validation failure `422`
- cross-hotel assignee denial
- admin user получает `403` для representative edit/update requests
- staff не может открыть edit/update
- disallowed attributes не меняются

**Checkpoint:**

```bash
bundle exec rspec spec/services/operations/tickets/manager_update_service_spec.rb spec/requests/operations/tickets_manager_spec.rb
```

---

## Layer 6 — Slice 4: Staff читает видимые tickets

### Step 6.1 — Завершить staff read authorization

**Файл:** `app/controllers/operations/tickets_controller.rb`

Изменить authorization для `index` и `show`, не меняя manager-only `edit/update`:

- `index` разрешен manager и staff; для обоих ролей tickets выбираются через `Operations::Tickets::VisibleTicketsQuery`
- `show` разрешен manager и staff
- manager `show` продолжает искать ticket через `current_hotel.tickets`
- staff `show` сначала ищет ticket через `current_hotel.tickets`, затем проверяет, что ticket id присутствует в `Operations::Tickets::VisibleTicketsQuery.call(staff: current_staff)`; иначе возвращает `404`
- `edit` и `update` остаются manager-only и для staff возвращают `403`

**Готово, когда:** staff users могут читать personally assigned и same-department tickets, но не могут читать unrelated same-hotel или cross-hotel tickets.

### Step 6.2 — Добавить staff ticket read request specs

**Создать файл:** `spec/requests/operations/tickets_staff_spec.rb`

Покрыть:

- index включает personally assigned ticket
- index включает same-department ticket
- index исключает unrelated department ticket
- index исключает cross-hotel ticket
- show assigned ticket
- show same-department ticket
- show unrelated same-hotel ticket возвращает `404`
- edit/update возвращают `403`

**Checkpoint:**

```bash
bundle exec rspec spec/services/operations/tickets/visible_tickets_query_spec.rb spec/requests/operations/tickets_staff_spec.rb
```

---

## Layer 7 — Slice 5: Staff берет и завершает assigned tickets

### Step 7.1 — Добавить transition actions

**Файл:** `app/controllers/operations/tickets_controller.rb`

Добавить:

- `start`: только staff, same-hotel ticket lookup, вызвать `Operations::Tickets::StartService`
- `complete`: только staff, same-hotel ticket lookup, вызвать `Operations::Tickets::CompleteService`

Authorization order:

- `require_staff!` должен выполняться до ticket lookup, чтобы `manager` и `admin` получали `403` для transition actions независимо от `ticket_id`

Response behavior:

- success redirect на `/operations/tickets/:id` с flash `Ticket updated`
- service validation failure возвращает `422` и render `show`
- при failure перед render `show` выставить `@ticket` и `@result`, чтобы `app/views/operations/tickets/show.html.erb` мог вывести validation summary
- перед вызовом service скрывать от staff tickets, которых нет в visible tickets query, через `404`
- same-department visibility без personal assignment возвращает `422` из service, потому что ticket видим, но workflow action запрещен без personal assignment
- cross-hotel ticket lookup возвращает `404`
- manager при попытке start/complete получает `403`

### Step 7.2 — Добавить transition buttons в show view

**Файл:** `app/views/operations/tickets/show.html.erb`

Выводить:

- `Start` button только когда current user staff, ticket personally assigned и status `new`
- `Complete` button только когда current user staff, ticket personally assigned и status `in_progress`
- validation summary выводит `@result.messages`, когда transition action рендерит `show` со статусом `422`

Использовать `button_to` с `method: :patch`.

### Step 7.3 — Добавить transition request specs

**Создать файл:** `spec/requests/operations/ticket_transitions_spec.rb`

Покрыть:

- assigned staff starts `new` ticket
- assigned staff completes `in_progress` ticket
- direct complete из `new` возвращает `422`
- starting `done` или `canceled` возвращает `422`
- same-department unassigned ticket возвращает `422`
- unrelated same-hotel ticket возвращает `404`
- cross-hotel ticket возвращает `404`
- manager start/complete возвращает `403`
- admin start/complete возвращает `403`
- success flash равен `Ticket updated`

**Checkpoint:**

```bash
bundle exec rspec spec/services/operations/tickets/start_service_spec.rb spec/services/operations/tickets/complete_service_spec.rb spec/requests/operations/ticket_transitions_spec.rb
```

---

## Layer 8 — Regression и end-to-end workflow

### Step 8.1 — Добавить admin regression request spec

**Создать или расширить файл:** `spec/requests/admin/access_spec.rb`

Проверить, что `/admin/**` остается admin-only после operations changes:

- admin может открыть representative admin endpoints
- manager получает redirect на `root_path` согласно текущему `Admin::BaseController#require_admin!`
- staff получает redirect на `root_path` согласно текущему `Admin::BaseController#require_admin!`
- no credentials все еще возвращают `401` с `Basic realm="Admin"`
- operations auth changes не меняют admin realm
- existing admin request setup остается валидным после Step 0.3/0.4, то есть staff fixtures создаются с department только там, где это требуется ролью `staff`

**Checkpoint:**

```bash
bundle exec rspec spec/requests/admin/access_spec.rb
```

### Step 8.2 — Добавить end-to-end operations request spec

**Создать файл:** `spec/requests/operations/staff_ticket_workflow_spec.rb`

Сценарий:

1. Создать hotel, manager, department, guest и ticket в статусе `new`.
2. Аутентифицироваться как manager, никогда как admin.
3. Manager создает same-hotel staff user с department.
4. Manager назначает ticket этому staff user.
5. Аутентифицироваться как staff.
6. Staff видит ticket в `/operations/tickets`.
7. Staff переводит ticket в работу.
8. Staff завершает ticket.
9. После reload ticket status равен `done`.
10. Manager из другого hotel получает `404` для ticket.
11. Staff из другого hotel получает `404` для ticket.

**Готово, когда:** полный workflow проходит без использования admin credentials.

### Step 8.3 — Полная acceptance-проверка

Запустить:

```bash
bundle exec rspec
bundle exec rubocop
```

Если RuboCop показывает pre-existing unrelated offenses, зафиксировать их отдельно и оставить feature changes чистыми.

---

## Рекомендуемый порядок реализации для агентов

1. Data agent: только Layer 0.
2. Auth/shell agent: только Layer 1 после Layer 0.
3. Services agent: только Layer 2 после Layer 0.
4. Staff management agent: Layer 3 после Layers 1-2.
5. Manager tickets agent: Layers 4-5 после Layers 1-2.
6. Staff tickets agent: Layers 6-7 после Layers 4-5.
7. Acceptance agent: Layer 8 после всех vertical slices.

Не редактировать параллельно один и тот же controller/views без явного разделения ownership: `Operations::TicketsController` и ticket views затрагиваются несколькими slices.

## Финальный checkpoint

```bash
bundle exec rspec
bundle exec rubocop
```
