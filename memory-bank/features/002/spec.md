# Spec — Feature 002: Role-based authorization & Hotel CRUD

**Brief:** memory-bank/features/002/brief.md
**Issue:** https://github.com/Melchakovartem/hotel_concierge_bot/issues/3

## 1. Scope

- Ограничить доступ к `/admin/**` только для роли `admin` (302 → `/` для остальных)
- Добавить `slug` к модели Hotel
- Полный CRUD отелей через `/admin/hotels`
- Вложенные read-only эндпоинты: hotel-scoped staff и tickets

Вне scope: CRUD для staff/tickets, namespace-разделы для manager/staff.

> **Предупреждение о scope:** спека сознательно консолидирует features 002–005 и затрагивает 6+ модулей (Hotel, Ticket, Admin::BaseController, HotelsController, HotelStaffController, HotelTicketsController, BaseService/Result). **TAUS/Scoped: намеренно нарушен, риск принят.** Реализовывать строго в порядке, указанном в §1.1 — ошибка в раннем слое блокирует последующие. При падении тестов на чекпоинте — починить, не переходя к следующему слою.

## 1.1 Порядок реализации (vertical slices)

Реализовывать строго в следующем порядке для каждого маршрута:

1. Миграция + изменения модели, необходимые для текущего роута
2. Роут
3. Action в контроллере
4. View
5. Тесты

Начать с инфраструктуры (`BaseService`, `Result`), затем авторизация (`require_admin!`),
затем Hotel CRUD slice за slice, затем вложенные ресурсы.

**Чекпоинты:** после завершения каждого слоя обязательно запустить `bundle exec rspec`.
Ожидаемый результат — 0 новых упавших тестов перед переходом к следующему слою:

1. После инфраструктуры (`BaseService`, `Result`) — `bundle exec rspec spec/services/`
2. После авторизации (`require_admin!`) — `bundle exec rspec spec/requests/`
3. После каждого Hotel CRUD-экшена — `bundle exec rspec spec/requests/admin/hotels_spec.rb`
4. После вложенных ресурсов — `bundle exec rspec spec/requests/admin/hotel_staff_spec.rb spec/requests/admin/hotel_tickets_spec.rb`

---

## 2. Изменения в БД

### Миграция 1: добавить `slug` к `hotels`

```ruby
add_column :hotels, :slug, :string, null: false
add_index :hotels, :slug, unique: true
```

Предполагается, что таблица `hotels` пуста на момент выполнения миграции (dev/staging окружение).
Если в таблице есть данные — использовать трёхшаговый подход: добавить колонку без ограничения,
сделать бэкфилл (`Hotel.find_each { |h| h.update_column(:slug, "#{h.name.parameterize}-slug") }`),
затем установить `null: false` через `change_column_null`.

### Миграция 2: добавить `hotel_id` к `tickets`

```ruby
add_reference :tickets, :hotel, null: false, foreign_key: true
```

Предполагается, что таблица `tickets` пуста на момент выполнения миграции.
Если в таблице есть данные — добавить сначала без `null: false`, привязать существующие тикеты
к отелю вручную, затем установить ограничение через `change_column_null`.
Индекс создаётся автоматически через `add_reference`.

### Миграция 3: добавить `subject` и `body` к `tickets`

```ruby
add_column :tickets, :subject, :string, null: false, default: ""
add_column :tickets, :body,    :text,   null: false, default: ""
```

`subject` — краткая тема тикета; `body` — текст запроса гостя.

---

## 3. Модель `Hotel`

**Валидации (добавить):**

```ruby
validates :name,     presence: true, uniqueness: true
validates :timezone, presence: true
validates :slug,     presence: true,
                     uniqueness: true,
                     format: { with: /\A[a-z0-9-]+\z/ }
```

Формат slug: только строчные латинские буквы, цифры и дефис. Любой другой символ —
ошибка валидации.

**Генерация slug:**

Slug формируется автоматически в `Admin::Hotels::CreateService` по правилу:

```ruby
slug = "#{params[:name].to_s.parameterize}-slug"
# "Grand Hotel" → "grand-hotel-slug"
```

Slug не принимается из пользовательского ввода и отсутствует в `hotel_params`.

Существующие ассоциации (`dependent: :restrict_with_exception`) уже правильные — не менять.

---

## 4. Маршруты

```ruby
namespace :admin do
  root "hotels#index"

  resources :hotels, param: :slug do
    resources :staff,   only: %i[index show], controller: "hotel_staff"
    resources :tickets, only: :index,          controller: "hotel_tickets"
  end

  # глобальные списки (существующие) — оставить
  resources :staff,   only: :index
  resources :tickets, only: :index
end
```

Итоговые пути:

| Method | Path                                  | Controller#Action             |
|--------|---------------------------------------|-------------------------------|
| GET    | /admin/hotels                         | admin/hotels#index            |
| GET    | /admin/hotels/new                     | admin/hotels#new              |
| POST   | /admin/hotels                         | admin/hotels#create           |
| GET    | /admin/hotels/:slug                   | admin/hotels#show             |
| GET    | /admin/hotels/:slug/edit              | admin/hotels#edit             |
| PATCH  | /admin/hotels/:slug                   | admin/hotels#update           |
| DELETE | /admin/hotels/:slug                   | admin/hotels#destroy          |
| GET    | /admin/hotels/:hotel_slug/staff       | admin/hotel_staff#index       |
| GET    | /admin/hotels/:hotel_slug/staff/:id   | admin/hotel_staff#show        |
| GET    | /admin/hotels/:hotel_slug/tickets     | admin/hotel_tickets#index     |

---

## 5. Авторизация

### 5.1 BaseController

Добавить `before_action :require_admin!` после `authenticate_staff!`:

```ruby
before_action :authenticate_staff!
before_action :require_admin!

private

def require_admin!
  redirect_to root_path unless @current_staff.admin?
end
```

Это заменяет существующий `require_hotel_access!` в HotelsController — метод удалить.
StaffController и TicketsController получат защиту автоматически.

**Следствие:** manager и staff при обращении к любому `/admin/**` эндпоинту
получают 302 → `/` (не 403). Существующий тест `returns 403 for staff role` в
`spec/requests/admin/hotels_spec.rb` нужно обновить на 302.

### 5.2 Матрица доступа

| Роль    | `/admin/**` | Результат                                    |
|---------|-------------|----------------------------------------------|
| admin   | любой       | 200 (index/new/show/edit) или 302 (create/update/destroy success) |
| manager | любой       | 302 → `/`                                    |
| staff   | любой       | 302 → `/`                                    |
| нет auth| любой       | 401                                          |

### 5.3 Инварианты

- `Hotel.name` уникален глобально
- `Hotel.slug` уникален глобально, формат `/\A[a-z0-9-]+\z/`, не может быть пустым
- `Hotel.slug` генерируется автоматически в `CreateService` по правилу `"#{name.parameterize}-slug"`; не принимается из формы
- `Hotel.slug` не изменяется после создания (edit/update не допускает смену slug; slug отсутствует в `hotel_params`)
- `Ticket.hotel_id` NOT NULL с FK-ограничением — тикет всегда привязан к отелю
- Отель нельзя удалить при наличии связанных `tickets` или `staff` (`restrict_with_exception`)
- Порядок `before_action` в `Admin::BaseController`: `authenticate_staff!` → `require_admin!`

---

## 6. Hotel CRUD

### 6.0 Инфраструктура сервисов (создать первым)

**`BaseService`** (`app/services/base_service.rb`):

```ruby
class BaseService
  extend Dry::Initializer

  class << self
    def call(**args)
      new(**args).call
    end
  end

  private

  def success(result: nil)
    Result.new(success: true, result:)
  end

  def failure(error_code:, messages:, result: nil)
    Result.new(success: false, error_code:, messages:, result:)
  end
end
```

**`Result`** (`app/services/result.rb`):

```ruby
Result = Data.define(:success, :error_code, :messages, :result) do
  def success? = success
  def failure? = !success

  def self.new(success:, result: nil, error_code: nil, messages: [])
    super
  end
end
```

> Использовать `Data.define` — проект на Ruby 3.3.3, доступно.

### 6.1 Сервисные объекты

**`Admin::Hotels::CreateService`** (`app/services/admin/hotels/create_service.rb`):

```ruby
class Admin::Hotels::CreateService < BaseService
  option :params  # хэш разрешённых атрибутов из контроллера (name, timezone)

  def call
    slug = "#{params[:name].to_s.parameterize}-slug"
    hotel = Hotel.new(params.merge(slug: slug))
    if hotel.save
      success(result: hotel)
    else
      failure(error_code: :validation_failed, messages: hotel.errors.full_messages, result: hotel)
    end
  end
end
```

**`Admin::Hotels::UpdateService`** (`app/services/admin/hotels/update_service.rb`):

```ruby
class Admin::Hotels::UpdateService < BaseService
  option :hotel
  option :params

  def call
    if hotel.update(params)
      success(result: hotel)
    else
      failure(error_code: :validation_failed, messages: hotel.errors.full_messages, result: hotel)
    end
  end
end
```

### 6.2 HotelsController

```ruby
module Admin
  class HotelsController < BaseController
    before_action :set_hotel, only: %i[show edit update destroy]

    def index
      @hotels = Hotel.order(:name)
    end

    def show; end

    def new
      @hotel = Hotel.new
    end

    def create
      result = Admin::Hotels::CreateService.call(params: hotel_params)
      if result.success?
        redirect_to admin_hotels_path, notice: "Hotel was successfully created."
      else
        @hotel = result.result
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      result = Admin::Hotels::UpdateService.call(hotel: @hotel, params: hotel_params)
      if result.success?
        redirect_to admin_hotels_path, notice: "Hotel was successfully updated."
      else
        @hotel = result.result
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @hotel.destroy
      redirect_to admin_hotels_path, notice: "Hotel was successfully deleted."
    rescue ActiveRecord::DeleteRestrictionError
      redirect_to admin_hotels_path, alert: "Hotel has associated records and cannot be deleted."
    end

    private

    def set_hotel
      @hotel = Hotel.find_by!(slug: params[:slug])
    rescue ActiveRecord::RecordNotFound
      render plain: "Not Found", status: :not_found
    end

    def hotel_params
      params.require(:hotel).permit(:name, :timezone)
    end
  end
end
```

### 6.3 Поведение по статусам

| Сценарий                              | HTTP     | Ответ                                           |
|---------------------------------------|----------|-------------------------------------------------|
| create / update — успех               | 302      | redirect `/admin/hotels` + `flash[:notice]`     |
| create / update — невалидные данные   | 422      | re-render формы с ошибками                      |
| destroy — успех                       | 302      | redirect `/admin/hotels` + `flash[:notice]`     |
| destroy — есть связанные записи       | 302      | redirect `/admin/hotels` + `flash[:alert]`      |
| slug не найден (show/edit/update/destroy) | 404  | plain "Not Found"                               |

---

## 7. Вложенные ресурсы (read-only)

### 7.1 HotelStaffController

```ruby
module Admin
  class HotelStaffController < BaseController
    before_action :set_hotel

    def index
      @staff = @hotel.staff.order(:name)
    end

    def show
      @staff_member = @hotel.staff.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render plain: "Not Found", status: :not_found
    end

    private

    def set_hotel
      @hotel = Hotel.find_by!(slug: params[:hotel_slug])
    rescue ActiveRecord::RecordNotFound
      render plain: "Not Found", status: :not_found
    end
  end
end
```

### 7.2 HotelTicketsController

```ruby
module Admin
  class HotelTicketsController < BaseController
    before_action :set_hotel

    def index
      @tickets = @hotel.tickets.includes(:guest, :department, :staff).order(created_at: :desc)
    end

    private

    def set_hotel
      @hotel = Hotel.find_by!(slug: params[:hotel_slug])
    rescue ActiveRecord::RecordNotFound
      render plain: "Not Found", status: :not_found
    end
  end
end
```

Tickets теперь имеют прямой `hotel_id` и поля `subject`/`body`. Добавить в модели:

```ruby
# Hotel
has_many :tickets, dependent: :restrict_with_exception

# Ticket
belongs_to :hotel
validates :subject, presence: true
validates :body,    presence: true
```

**Необходимые изменения в фабриках и существующих спеках (выполнить в рамках реализации):**

- `spec/factories/hotels.rb` — добавить `sequence(:name) { |n| "Hotel #{n}" }` и `sequence(:slug) { |n| "hotel-#{n}" }`
- `spec/factories/tickets.rb` — добавить `association :hotel`, `subject { "Test subject" }`, `body { "Test body" }` (файл создать, если отсутствует)
- `spec/requests/admin/access_spec.rb` — в `Ticket.create!` добавить `hotel: hotel`

---

## 8. Вьюхи

## 8.1 hotels#index

Каждый отель отображается как ссылка `hotel.name` → `admin_hotel_path(hotel)`.
Рядом с каждым отелем — ссылки:
- `t(".edit_link")` → `edit_admin_hotel_path(hotel)`
- `t(".delete_link")` → `admin_hotel_path(hotel)`, method DELETE (с подтверждением)

При пустой коллекции — `t(".empty")`.

## 8.2 hotels#show

`GET /admin/hotels/:slug` — отображает:
- Название отеля, timezone, slug
- Ссылку с текстом `t(".staff_link")` → `admin_hotel_staff_index_path(hotel)`
- Ссылку с текстом `t(".tickets_link")` → `admin_hotel_tickets_path(hotel)`
- Ссылку с текстом `t(".edit_link")` → `edit_admin_hotel_path(hotel)`
- Ссылку с текстом `t(".delete_link")` → `admin_hotel_path(hotel)`, method DELETE (с подтверждением)

i18n-ключи (добавить в `en.yml` и `ru.yml`):

```yaml
# en.yml
en:
  admin:
    hotels:
      index:
        edit_link: "Edit"
        delete_link: "Delete"
      show:
        staff_link: "Staff"
        tickets_link: "Tickets"
        edit_link: "Edit"
        delete_link: "Delete"

# ru.yml
ru:
  admin:
    hotels:
      index:
        edit_link: "Редактировать"
        delete_link: "Удалить"
      show:
        staff_link: "Сотрудники"
        tickets_link: "Тикеты"
        edit_link: "Редактировать"
        delete_link: "Удалить"
```

## 8.3 Формы (new / edit)

Форма `new` содержит поля: `name`, `timezone`.
Форма `edit` содержит поля: `name`, `timezone`. Поле `slug` — **отсутствует** (не отображается).

Slug не доступен для редактирования ни в каком виде (ни readonly, ни скрытое поле).

**Отображение ошибок валидации:**

Создать partial `app/views/shared/_errors.html.erb`:

```erb
<% if object.errors.any? %>
  <div class="errors">
    <ul>
      <% object.errors.full_messages.each do |msg| %>
        <li><%= msg %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

Подключать в начале каждой формы (`new`, `edit`) через:

```erb
<%= render "shared/errors", object: @hotel %>
```

Использовать этот же partial во всех формах проекта (не создавать альтернативных механизмов вывода ошибок).

**Поле `timezone`** — select, реализован через Rails-хелпер `time_zone_select`:

```erb
<%= f.time_zone_select :timezone, ActiveSupport::TimeZone.all, { include_blank: "Select timezone" }, { class: "form-control" } %>
```

- Список: ~150 таймзон из `ActiveSupport::TimeZone.all` (friendly-имена: `"Moscow"`, `"Eastern Time (US & Canada)"`)
- Хранит строку в формате ActiveSupport (`"Moscow"`, не IANA `"Europe/Moscow"`)
- Без JS-зависимостей

## 8.4 hotel_staff#index

Каждый сотрудник отображает: `name`, `email`, `role`.
При пустой коллекции — `t(".empty")`.

## 8.5 hotel_staff#show

`Staff.belongs_to :hotel` — ассоциация существует (проверено по `app/models/staff.rb`).

Отображает поля staff-записи: `name`, `email`, `role`, `hotel.name` (через `@staff_member.hotel.name`).
Не отображает: `hotel_id` (raw FK), `password_digest`, `created_at`, `updated_at`.

## 8.6 hotel_tickets#index

Каждый тикет отображает: `subject`, `body`, `status`, `priority`, связанные `guest.name`, `department.name`, `staff.name`.
Если `ticket.staff` равен `nil` — отображать `t(".unassigned")` из локалей.
Не отображает: `created_at`, `updated_at`.
При пустой коллекции — `t(".empty")`.

Ассоциации модели `Ticket` (проверено по `app/models/ticket.rb`):
- `belongs_to :guest` — обязательная, nil невозможен → `ticket.guest.name`
- `belongs_to :department` — обязательная, nil невозможен → `ticket.department.name`
- `belongs_to :staff, optional: true` — может быть nil → `ticket.staff&.name || t(".unassigned")`

## 8.7 i18n — empty states

Файлы локалей: `config/locales/en.yml`, `config/locales/ru.yml`.

```yaml
# en.yml
en:
  admin:
    hotels:
      index:
        empty: "No hotels yet."
    hotel_staff:
      index:
        empty: "No staff members for this hotel."
    hotel_tickets:
      index:
        empty: "No tickets for this hotel."
        unassigned: "Unassigned"
```

```yaml
# ru.yml
ru:
  admin:
    hotels:
      index:
        empty: "Отели не добавлены."
    hotel_staff:
      index:
        empty: "У этого отеля нет сотрудников."
    hotel_tickets:
      index:
        empty: "У этого отеля нет тикетов."
        unassigned: "Не назначен"
```

Вьюха отображает строку `t(".empty")` при пустой коллекции.

---

## 9. Тестовое покрытие

Файлы spec:

```
spec/requests/admin/hotels_spec.rb         # CRUD + authorization
spec/requests/admin/hotel_staff_spec.rb    # hotel-scoped staff
spec/requests/admin/hotel_tickets_spec.rb  # hotel-scoped tickets
spec/services/admin/hotels/create_service_spec.rb
spec/services/admin/hotels/update_service_spec.rb
```

### 9.1 `hotels_spec.rb` — обязательные кейсы

**Авторизация (каждый эндпоинт):**
- admin → 200 для index/new/show/edit; 302 для create/update/destroy (success)
- manager → 302 (redirect to `/`)
- staff → 302 (redirect to `/`)
- нет auth → 401

**CRUD (только для admin):**

| Action  | Кейс                              | Ожидание                                                              | Что проверять в body                              |
|---------|-----------------------------------|-----------------------------------------------------------------------|---------------------------------------------------|
| index   | есть отели                        | 200                                                                   | body include `hotel.name`                         |
| index   | нет отелей                        | 200                                                                   | body include `t("admin.hotels.index.empty")`      |
| new     | success                           | 200                                                                   | —                                                 |
| create  | valid params                      | 302 → `/admin/hotels`, flash notice                                   | —                                                 |
| create  | missing name                      | 422                                                                   | —                                                 |
| create  | missing timezone                  | 422                                                                   | —                                                 |
| create  | duplicate name (→ duplicate slug) | 422                                                                   | body include `"Name has already been taken"` AND `"Slug has already been taken"` |
| show    | existing slug                     | 200                                                                   | body include `hotel.name`, `hotel.slug`, `hotel.timezone`; ссылки на `.../staff` и `.../tickets` |
| show    | unknown slug                      | 404                                                                   | —                                                 |
| edit    | existing slug                     | 200                                                                   | —                                                 |
| edit    | unknown slug                      | 404                                                                   | —                                                 |
| update  | valid params                      | 302 → `/admin/hotels`, flash notice                                   | —                                                 |
| update  | slug в params игнорируется        | slug отеля не изменился после запроса                                 | —                                                 |
| update  | validation failure (пустой name)  | 422                                                                   | body include `"Name can't be blank"`              |
| update  | unknown slug                      | 404                                                                   | —                                                 |
| destroy | no associated records             | 302, flash notice                                                     | —                                                 |
| destroy | has associated records            | 302, flash alert `"Hotel has associated records and cannot be deleted."` | —                                              |
| destroy | unknown slug                      | 404                                                                   | —                                                 |

### 9.2 `hotel_staff_spec.rb`

| Кейс                                             | Ожидание | Что проверять в body                              |
|--------------------------------------------------|----------|---------------------------------------------------|
| `GET /admin/hotels/:slug/staff` — есть сотрудники | 200     | body include `staff.name`                         |
| `GET /admin/hotels/:slug/staff` — нет сотрудников | 200     | body include `t("admin.hotel_staff.index.empty")` |
| `GET /admin/hotels/:slug/staff/:id` — принадлежит отелю | 200 | только HTTP 200, body не проверять           |
| `GET /admin/hotels/:slug/staff/:id` — другой отель | 404   | —                                                 |
| `GET /admin/hotels/unknown/staff`                | 404      | —                                                 |
| Авторизация (index): manager → 302 → `/`         | 302      | —                                                 |
| Авторизация (index): staff → 302 → `/`           | 302      | —                                                 |
| Авторизация (index): нет auth                    | 401      | —                                                 |

### 9.3 `hotel_tickets_spec.rb`

| Кейс                                               | Ожидание | Что проверять в body                                |
|----------------------------------------------------|----------|-----------------------------------------------------|
| `GET /admin/hotels/:slug/tickets` — есть тикеты   | 200      | body include `ticket.subject`                       |
| `GET /admin/hotels/:slug/tickets` — нет тикетов   | 200      | body include `t("admin.hotel_tickets.index.empty")` |
| `GET /admin/hotels/:slug/tickets` — тикет без staff | 200    | body include `t("admin.hotel_tickets.index.unassigned")` |
| `GET /admin/hotels/unknown/tickets`               | 404      | —                                                   |
| Авторизация (index): manager → 302 → `/`          | 302      | —                                                   |
| Авторизация (index): staff → 302 → `/`            | 302      | —                                                   |
| Авторизация (index): нет auth                     | 401      | —                                                   |

### 9.4 `create_service_spec.rb`

- valid params → Success, hotel сохранён; `hotel.slug == "#{name.parameterize}-slug"`
- missing name → Failure, hotel не сохранён, ошибки присутствуют
- missing timezone → Failure, hotel не сохранён, ошибки присутствуют
- duplicate name (→ duplicate slug) → Failure, ошибки присутствуют

### 9.5 `update_service_spec.rb`

- valid params → Success, hotel обновлён
- validation failure → Failure, ошибки присутствуют

---

## 10. Обновление существующих тестов

Файл `spec/requests/admin/hotels_spec.rb` содержит:

```ruby
it "returns 200 with hotel name for manager role" do ...
it "returns 403 for staff role" do ...
```

Оба кейса устарели после изменения авторизации:
- manager: 200 → **302 redirect to root**
- staff: 403 → **302 redirect to root**

Эти тесты нужно обновить (не удалять).

---

## 11. Решённые вопросы

| Вопрос | Решение |
|--------|---------|
| Паттерн сервисов | `BaseService` + `Result` PORO; `dry-monads` не используется |
| Hotel#tickets | Прямой `hotel_id` на tickets + `has_many :tickets` в Hotel + `belongs_to :hotel` в Ticket |
| Turbo | Не используется; статус 422 при re-render формы — стандартный HTTP, без turbo-специфики |
| Выбор таймзоны | `time_zone_select` с `ActiveSupport::TimeZone.all`; хранит ActiveSupport-строку; без JS |
| Ruby версия | 3.3.3 — `Data.define` доступен |
| Slug генерация | Автоматически в `CreateService`: `"#{name.parameterize}-slug"`; из формы не принимается |
| Slug в edit-форме | Поле отсутствует полностью |
| Empty states | i18n-ключи в `en.yml` и `ru.yml`; вьюха рендерит `t(".empty")` при пустой коллекции |
