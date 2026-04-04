# Implementation Plan: Система авторизации и подтверждения Email

**Spec:** `.memory-bank/features/001-auth-email/spec.md`  
**Статус:** Reviewed (v3 — 11 + 2 замечания ревью исправлены)  
**Дата:** 03.04.2026

---

## Текущее состояние проекта

- **Rails 8.1.3**, Vite 8, React 19, Inertia.js 3, Tailwind CSS 4
- **Нет** gems: `devise`, `sidekiq`, `redis`, `rspec-rails`, `factory_bot_rails`, `letter_opener_web`
- **Нет** модели `User`, нет миграций, нет `db/schema.rb`
- **Нет** `spec/` директории (RSpec не подключён)
- **Docker:** web + db (PostgreSQL 17). Нет Redis, нет Sidekiq worker
- **Frontend:** `app/frontend/` (Vite + React + TS), entrypoint `inertia.tsx`, pages в `app/frontend/pages/`
- **Порт:** приложение на `3100`, Vite dev server на `3036`
- **Mailer default_url_options:** port `3000` (нужно исправить на `3100`)
- **Locale:** только `en.yml` (stub)

---

## Фаза 0: Подготовка инфраструктуры (Gems + Docker)

### Step 0.1 — Добавить gems в Gemfile

**Файл:** `video_chat_and_translator/Gemfile`

**Действие:** Добавить следующие гемы:

```ruby
# Auth
gem "devise", "~> 4.9"

# Background processing
gem "redis", "~> 5.0"
gem "sidekiq", "~> 8.0"

group :development, :test do
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails", "~> 6.0"
end

group :development do
  gem "letter_opener_web", "~> 3.0"
end
```

> **⚠️ Требует разрешения пользователя на установку гемов.**

**Затем:** `bundle install` внутри Docker-контейнера.

---

### Step 0.2 — Добавить Redis-контейнер в Docker Compose + настроить cable.yml и ENV

#### 0.2.1 — Сервис Redis в Docker Compose

**Файл:** `docker/docker-compose.yml`

**Действие:** Добавить сервис `redis`:

```yaml
redis:
  image: redis:7-alpine
  ports:
    - "6379"
  volumes:
    - redis_data:/data
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 5s
    timeout: 5s
    retries: 5
  networks:
    - video_chat_network
```

**Добавить volume** `redis_data` в секцию `volumes`:

```yaml
volumes:
  postgres_data:
  bundle_cache:
  node_modules:
  redis_data:
```

#### 0.2.2 — Обновить сервис `web`: зависимость + переменные окружения

**Файл:** `docker/docker-compose.yml`

**Действие:** В сервисе `web` добавить зависимость от `redis` и переменную `REDIS_URL`:

```yaml
web:
  environment:
    - DATABASE_URL=postgres://postgres:postgres@db:5432/video_chat_and_translator_development
    - REDIS_URL=redis://redis:6379/0          # <-- добавить
    - RAILS_ENV=development
    - VITE_RUBY_HOST=0.0.0.0
    - PORT=3100
    - BINDING=0.0.0.0
  depends_on:
    db:
      condition: service_healthy
    redis:                                     # <-- добавить
      condition: service_healthy
```

#### 0.2.3 — Добавить REDIS_URL в .env (документация для разработчика)

> **Примечание:** `cable.yml` в development остаётся `adapter: async`. Action Cable не используется в фиче авторизации. Переключение на Redis произойдёт позже, когда понадобится Action Cable (например, для видео-чата). Sidekiq настраивается отдельно через `REDIS_URL`.

**Файл:** `.env`

**Действие:** Добавить переменную (как reference для локальной разработки вне Docker):

```env
REDIS_URL=redis://localhost:6379/0
```

> Внутри Docker эта переменная перекрывается значением из `docker-compose.yml` (`redis://redis:6379/0`), но наличие в `.env` документирует зависимость проекта от Redis.

---

### Step 0.3 — Добавить Sidekiq worker-контейнер в Docker Compose

**Файл:** `docker/docker-compose.yml`

**Действие:** Добавить сервис `sidekiq`:

```yaml
sidekiq:
  build:
    context: ../video_chat_and_translator
    dockerfile: ../docker/Dockerfile
  command: bundle exec sidekiq
  volumes:
    - ../video_chat_and_translator:/app
    - bundle_cache:/usr/local/bundle
  environment:
    - DATABASE_URL=postgres://postgres:postgres@db:5432/video_chat_and_translator_development
    - REDIS_URL=redis://redis:6379/0
    - RAILS_ENV=development
  depends_on:
    db:
      condition: service_healthy
    redis:
      condition: service_healthy
  networks:
    - video_chat_network
```

---

### Step 0.4 — Настроить Active Job на Sidekiq adapter

**Файл:** `video_chat_and_translator/config/application.rb`

**Действие:** Добавить в блок `class Application`:

```ruby
config.active_job.queue_adapter = :sidekiq
```

---

### Step 0.5 — Создать конфигурацию Sidekiq

**Файл (создать):** `video_chat_and_translator/config/sidekiq.yml`

```yaml
:concurrency: 5
:queues:
  - default
  - mailers
```

---

### ~~Step 0.6~~ — УДАЛЁН

> Sidekiq 8+ автоматически читает `REDIS_URL` из ENV. Отдельный initializer с `Sidekiq.configure_server/configure_client` избыточен. Initializer понадобится только при нестандартной конфигурации Redis (отдельные БД, пароли, SSL). На данном этапе `REDIS_URL` из `docker-compose.yml` достаточен.

---

## Фаза 1: Devise + модель User + миграция

### Step 1.1 — Инициализировать Devise

**Команда:** `rails generate devise:install`

**Создаёт:**
- `config/initializers/devise.rb`

**Действие после генерации:** В `config/initializers/devise.rb` настроить:

```ruby
config.mailer_sender = 'noreply@videochat.local'
config.confirm_within = 24.hours
config.reconfirmable = false
```

---

### Step 1.2 — Сгенерировать модель User через Devise

**Команда:** `rails generate devise User`

> **⚠️ Требует разрешения пользователя на создание миграции.**

**Создаёт:**
- `app/models/user.rb`
- `db/migrate/XXXXXX_devise_create_users.rb`

**Действие в миграции:** Раскомментировать секцию `## Confirmable`:

```ruby
t.string   :confirmation_token
t.datetime :confirmed_at
t.datetime :confirmation_sent_at
t.string   :unconfirmed_email
```

И раскомментировать индекс:

```ruby
add_index :users, :confirmation_token, unique: true
```

---

### Step 1.3 — Настроить модель User

**Файл:** `video_chat_and_translator/app/models/user.rb`

**Действие:** Убедиться, что подключён модуль `:confirmable`:

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :confirmable, :validatable
end
```

---

### Step 1.4 — Запустить миграцию

**Команда:** `rails db:migrate`

**Результат:** Создаётся таблица `users` с полями email, encrypted_password, confirmation_token, confirmed_at, confirmation_sent_at и индексами.

---

## Фаза 2: Routing

### Step 2.1 — Настроить Devise routes

**Файл:** `video_chat_and_translator/config/routes.rb`

**Действие:** Добавить маршруты Devise с кастомными контроллерами:

```ruby
Rails.application.routes.draw do
  # Redirect 127.0.0.1 → localhost (необходим для корректной работы Vite dev server)
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    confirmations: "users/confirmations"
  }

  # Повторная отправка confirmation email (AC#5: кнопка «Не пришло письмо?»)
  namespace :users do
    namespace :confirmations do
      resource :resend, only: [:create]
    end
  end

  # letter_opener_web (development only)
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  authenticate :user do
    root "pages#index", as: :authenticated_root
  end

  devise_scope :user do
    root "users/sessions#new"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

---

## Фаза 3: Контроллеры (Devise + Inertia.js)

### Step 3.1 — Создать concern ConfirmableLoginHandler

**Файл (создать):** `video_chat_and_translator/app/controllers/concerns/confirmable_login_handler.rb`

**Действие:** Concern с логикой из спеки — если ссылка истекла и пользователь пробует авторизоваться, отправлять новую ссылку; если ссылка ещё живая — показать сообщение без повторной отправки:

```ruby
module ConfirmableLoginHandler
  extend ActiveSupport::Concern

  private

  def handle_unconfirmed_user(user)
    return unless user && !user.confirmed?

    if user.confirmation_period_expired?
      user.resend_confirmation_instructions
      redirect_to new_user_session_path,
                  alert: I18n.t("auth.login.confirmation_resent")
    else
      redirect_to new_user_session_path,
                  alert: I18n.t("auth.login.unconfirmed")
    end
  end
end
```

---

### Step 3.2 — Создать Users::SessionsController (с ConfirmableLoginHandler)

**Файл (создать):** `video_chat_and_translator/app/controllers/users/sessions_controller.rb`

**Действие:** Контроллер создаётся сразу с финальной логикой — include concern и обработка unconfirmed пользователей в `create`:

```ruby
class Users::SessionsController < Devise::SessionsController
  include ConfirmableLoginHandler

  skip_before_action :authenticate_user!

  def new
    render inertia: "auth/Login", props: {
      translations: I18n.t("auth.login")
    }
  end

  def create
    self.resource = warden.authenticate(auth_options)

    if resource
      sign_in(resource_name, resource)
      redirect_to authenticated_root_path, notice: I18n.t("devise.sessions.signed_in")
    else
      user = User.find_by(email: params.dig(:user, :email))
      if user&.valid_password?(params.dig(:user, :password)) && !user.confirmed?
        handle_unconfirmed_user(user)
      else
        redirect_to new_user_session_path, alert: I18n.t("auth.login.invalid_credentials")
      end
    end
  end

  def destroy
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    redirect_to new_user_session_path
  end
end
```

---

### Step 3.3 — Создать Users::RegistrationsController

**Файл (создать):** `video_chat_and_translator/app/controllers/users/registrations_controller.rb`

**Действие:** При ошибке валидации используется `render inertia:` (не `redirect_to`), чтобы ошибки дошли до React-компонента как props:

```ruby
class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_action :authenticate_user!

  def new
    render inertia: "auth/Register", props: {
      translations: I18n.t("auth.register")
    }
  end

  def create
    build_resource(sign_up_params)

    if resource.save
      redirect_to new_user_registration_path,
                  notice: I18n.t("auth.register.success")
    else
      render inertia: "auth/Register", props: {
        translations: I18n.t("auth.register"),
        errors: resource.errors.to_hash(true)
      }
    end
  end

  private

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
```

> **Важно:** `render inertia:` вместо `redirect_to` — при редиректе props теряются, т.к. Inertia делает новый GET-запрос. `render` сохраняет данные в текущем ответе.

---

### Step 3.4 — Создать Users::ConfirmationsController

**Файл (создать):** `video_chat_and_translator/app/controllers/users/confirmations_controller.rb`

**Действие:**

```ruby
class Users::ConfirmationsController < Devise::ConfirmationsController
  skip_before_action :authenticate_user!

  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])

    if resource.errors.empty?
      redirect_to new_user_session_path,
                  notice: I18n.t("auth.confirmation.confirmed")
    else
      redirect_to new_user_session_path,
                  alert: I18n.t("auth.confirmation.invalid_token")
    end
  end
end
```

---

### Step 3.5 — Создать Users::Confirmations::ResendsController (AC#5)

**Файл (создать):** `video_chat_and_translator/app/controllers/users/confirmations/resends_controller.rb`

**Действие:** Кнопка «Не пришло письмо?» на странице Login отправляет POST на этот endpoint. Контроллер соответствует архитектурному правилу проекта (только CRUD-actions):

```ruby
class Users::Confirmations::ResendsController < ApplicationController
  skip_before_action :authenticate_user!

  def create
    user = User.find_by(email: params[:email])

    if user && !user.confirmed?
      user.resend_confirmation_instructions
      redirect_to new_user_session_path,
                  notice: I18n.t("auth.confirmation.resend_success")
    else
      redirect_to new_user_session_path,
                  alert: I18n.t("auth.confirmation.resend_not_found")
    end
  end
end
```

---

### Step 3.6 — Обновить ApplicationController

**Файл:** `video_chat_and_translator/app/controllers/application_controller.rb`

**Действие:** Добавить `before_action :authenticate_user!` и Inertia shared data (включая `flash` для toast-уведомлений):

```ruby
class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  before_action :authenticate_user!

  inertia_share flash: -> { flash.to_hash }
  inertia_share current_user: -> { current_user&.as_json(only: [:id, :email]) }
end
```

> **Примечание:** `skip_before_action :authenticate_user!` уже включён в каждый Devise-контроллер (Steps 3.2–3.5), поэтому отдельный шаг для этого не нужен.

> **Примечание по i18n:** Переводы передаются каждому Inertia-компоненту через props из соответствующего контроллера (`translations: I18n.t("auth.login")` и т.д.). Это обеспечивает:
> - Только нужные переводы попадают на фронтенд (не весь locale-файл)
> - TypeScript типизация через интерфейс props (см. Step 4.3, 4.4)
> - Нет необходимости в глобальном `inertia_share` для переводов

---

## Фаза 4: React-страницы (Frontend)

### Step 4.1 — Создать shared Layout компонент для auth

**Файл (создать):** `video_chat_and_translator/app/frontend/pages/auth/AuthLayout.tsx`

**Действие:** Общая обёртка для страниц авторизации — центрирование, border, rounded-md:

```tsx
// Минималистичный layout: форма по центру страницы,
// border + rounded-md (по спеке)
```

---

### Step 4.2 — Создать компонент Toast-уведомлений

**Файл (создать):** `video_chat_and_translator/app/frontend/components/Toast.tsx`

**Действие:** Компонент, который считывает `flash` из Inertia shared data и показывает toast (зелёный для `notice`, красный для `alert`). Автоматически скрывается через 5 секунд.

---

### Step 4.3 — Создать страницу Login

**Файл (создать):** `video_chat_and_translator/app/frontend/pages/auth/Login.tsx`

**TypeScript интерфейс props:**

```tsx
interface LoginTranslations {
  title: string
  email: string
  password: string
  submit: string
  no_account: string
  register_link: string
  resend_email: string
}

interface LoginProps {
  translations: LoginTranslations
  flash?: { notice?: string; alert?: string }
}
```

**Действие:** Форма авторизации:
- Поля: email, password
- Кнопка «Войти»
- Ссылка на регистрацию
- **Кнопка «Не пришло письмо?»** (AC#5) — показывает поле email + POST на `/users/confirmations/resend`
- При отправке — spinner вместо полей (пока loading)
- Баннер ошибки (красный фон, белый текст) при неверных credentials или серверной ошибке
- Flash-сообщения через shared data (`flash` prop из `inertia_share`)
- Все тексты из `translations` prop (от backend через `I18n.t("auth.login")`)
- Tailwind классы: `rounded-md`, border, центрирование

---

### Step 4.4 — Создать страницу Register

**Файл (создать):** `video_chat_and_translator/app/frontend/pages/auth/Register.tsx`

**TypeScript интерфейс props:**

```tsx
interface RegisterTranslations {
  title: string
  email: string
  password: string
  password_confirmation: string
  submit: string
  have_account: string
  login_link: string
}

interface RegisterProps {
  translations: RegisterTranslations
  errors?: Record<string, string[]>
  flash?: { notice?: string; alert?: string }
}
```

**Действие:** Форма регистрации:
- Поля: email, password, password_confirmation
- Кнопка «Зарегистрироваться»
- Ссылка на авторизацию
- Валидация: красная рамка на невалидном поле + текст ошибки под полем (из `errors` prop)
- Баннер успеха (зелёный фон) после регистрации — из `flash.notice`
- Все тексты из `translations` prop (от backend через `I18n.t("auth.register")`)
- Tailwind: `rounded-md`, border, центрирование

---

### Step 4.5 — Обновить Landing.tsx для авторизованных пользователей

**Файл:** `video_chat_and_translator/app/frontend/pages/Landing.tsx`

**Действие:** Добавить отображение toast-уведомления (flash notice о успешной авторизации). Добавить кнопку «Выйти».

---

## Фаза 5: Localization (русская локализация)

### Step 5.1 — Создать файл русской локализации

**Файл (создать):** `video_chat_and_translator/config/locales/ru.yml`

**Действие:** Добавить все тексты для auth:

```yaml
ru:
  auth:
    login:
      title: "Авторизация"
      email: "Электронная почта"
      password: "Пароль"
      submit: "Войти"
      no_account: "Нет аккаунта?"
      register_link: "Зарегистрироваться"
      invalid_credentials: "Неверный эмэйл или пароль"
      resend_email: "Не пришло письмо?"
      server_error: "Возникли технические неполадки, попробуйте позже"
      unconfirmed: "У вас неподтверждён эмэйл, подтвердите эмэйл по ссылке, которая была выслана вам на почту. Если вы не видите эмэйла, то проверьте папку Спам или же свяжитесь с администратором admin@xyz.xyz"
      confirmation_resent: "Новая ссылка с подтверждением почты была выслана вам на почту, если вы не видите ссылки, то проверьте папку Спам или свяжитесь с администратором admin@xyz.xyz"
    register:
      title: "Регистрация"
      email: "Электронная почта"
      password: "Пароль"
      password_confirmation: "Подтверждение пароля"
      submit: "Зарегистрироваться"
      have_account: "Уже есть аккаунт?"
      login_link: "Войти"
      success: "Вы успешно зарегистрированы! Письмо с подтверждением было отправлено на вашу почту."
      success_with_delay: "Аккаунт создан. Проверьте вашу почту для подтверждения. Письмо может прийти с задержкой — рекомендуем также проверить папку Спам."
    confirmation:
      confirmed: "Ваш эмэйл успешно подтверждён. Теперь вы можете войти."
      invalid_token: "Ссылка подтверждения недействительна или устарела."
      resend_success: "Письмо с подтверждением было повторно отправлено на вашу почту."
      resend_not_found: "Пользователь с таким эмэйлом не найден или уже подтверждён."
    errors:
      email_invalid: "Некорректный формат эмэйла"
      email_taken: "Этот эмэйл уже зарегистрирован"
      password_too_short: "Пароль должен содержать минимум 8 символов"
      password_mismatch: "Пароли не совпадают"
  devise:
    sessions:
      signed_in: "Вы успешно авторизовались"
      signed_out: "Вы вышли из системы"
```

---

### Step 5.2 — Установить русский язык по умолчанию

**Файл:** `video_chat_and_translator/config/application.rb`

**Действие:** Добавить:

```ruby
config.i18n.default_locale = :ru
config.i18n.available_locales = [:ru, :en]
```

---

## Фаза 6: Mailer + letter_opener_web

### Step 6.1 — Настроить Devise mailer на deliver_later (Sidekiq)

**Файл:** `video_chat_and_translator/config/initializers/devise.rb`

**Действие:** После генерации initializer убедиться, что строка присутствует:

```ruby
config.parent_mailer = "ActionMailer::Base"
```

А в `config/application.rb` (уже добавлено в Step 0.4): `config.active_job.queue_adapter = :sidekiq` — это гарантирует, что `deliver_later` уйдёт в Sidekiq.

---

### Step 6.2 — Настроить letter_opener_web в development

**Файл:** `video_chat_and_translator/config/environments/development.rb`

**Действие:** Изменить delivery method и порт:

```ruby
config.action_mailer.delivery_method = :letter_opener_web
config.action_mailer.default_url_options = { host: "localhost", port: 3100 }
config.action_mailer.perform_deliveries = true
```

---

### Step 6.3 — Маршрут letter_opener_web

Уже включено в Step 2.1 (`mount LetterOpenerWeb::Engine, at: "/letter_opener"`).

---

## Фаза 7: Настройка RSpec

### Step 7.1 — Инициализировать RSpec

**Команда:** `rails generate rspec:install`

**Создаёт:**
- `spec/spec_helper.rb`
- `spec/rails_helper.rb`
- `.rspec`

---

### Step 7.2 — Настроить FactoryBot и Devise helpers в RSpec

**Файл:** `video_chat_and_translator/spec/rails_helper.rb`

**Действие:** Добавить:

```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::IntegrationHelpers, type: :request
end
```

---

### Step 7.3 — Создать фабрику User

**Файл (создать):** `video_chat_and_translator/spec/factories/users.rb`

```ruby
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
      unconfirmed
      confirmation_sent_at { 25.hours.ago }
    end
  end
end
```

---

## Фаза 8: Интеграционные тесты

### Step 8.1 — Тесты регистрации

**Файл (создать):** `video_chat_and_translator/spec/requests/users/registrations_spec.rb`

**Сценарии:**
1. Успешная регистрация — создаётся User, `confirmed_at` nil, редирект, flash
2. Невалидный email — ошибка валидации, User не создан
3. Дубликат email — ошибка "already taken"
4. Пароль < 8 символов — ошибка валидации
5. Пароли не совпадают — ошибка валидации
6. Письмо отправляется в очередь после регистрации

---

### Step 8.2 — Тесты авторизации

**Файл (создать):** `video_chat_and_translator/spec/requests/users/sessions_spec.rb`

**Сценарии:**
1. Успешная авторизация подтверждённого пользователя — редирект на root
2. Неверный email — ошибка, остаёмся на login
3. Неверный пароль — ошибка, остаёмся на login
4. Вход с неподтверждённой почтой (ссылка ещё живая) — сообщение "подтвердите эмэйл"
5. Вход с неподтверждённой почтой (ссылка истекла) — новая ссылка отправлена, flash-сообщение
6. Выход — редирект на login

---

### Step 8.3 — Тесты подтверждения email

**Файл (создать):** `video_chat_and_translator/spec/requests/users/confirmations_spec.rb`

**Сценарии:**
1. Переход по валидной ссылке — `confirmed_at` заполнен, редирект на login
2. Переход по истёкшей ссылке (через 24ч) — ошибка "token invalid"
3. Переход по уже использованной ссылке — ошибка "token invalid"

---

### Step 8.4 — Тесты повторной отправки confirmation (AC#5)

**Файл (создать):** `video_chat_and_translator/spec/requests/users/confirmations/resends_spec.rb`

**Сценарии:**
1. POST с email неподтверждённого пользователя — письмо отправляется повторно, flash notice
2. POST с email уже подтверждённого пользователя — flash alert "не найден или подтверждён"
3. POST с несуществующим email — flash alert "не найден или подтверждён"

---

### Step 8.5 — Тест доступа неавторизованного пользователя

**Файл (создать):** `video_chat_and_translator/spec/requests/pages_spec.rb`

**Сценарии:**
1. Неавторизованный пользователь → редирект на login
2. Авторизованный подтверждённый пользователь → видит главную страницу

---

## Фаза 9: Документация

### Step 9.1 — Создать документацию для auth-модуля

**Файл (создать):** `video_chat_and_translator/docs/auth-email.md`

**Действие:** Описать:
- Архитектуру auth (Devise + Inertia)
- Контроллеры и их actions
- Concern `ConfirmableLoginHandler` — логика повторной отправки
- React-страницы и их props
- Маршруты
- Фоновые задачи (Sidekiq)
- Локализация

---

## Фаза 10: Скриншоты (AC#6)

### Step 10.1 — Создать скриншоты UI-сценариев через playwright-cli

**Директория:** `screenshots/001-auth-email/`

**Утилита:** `playwright-cli` (уже присутствует в проекте)

**Действие:** Для каждого UI-сценария из спеки сделать скриншот и сохранить в директорию:

| # | Сценарий | Файл скриншота |
|---|----------|----------------|
| 1 | Страница авторизации — пустая форма | `login-empty.png` |
| 2 | Авторизация — неверный email/пароль (красный баннер) | `login-error-invalid-credentials.png` |
| 3 | Авторизация — spinner при отправке | `login-loading-spinner.png` |
| 4 | Авторизация — успех (toast зелёный) | `login-success-toast.png` |
| 5 | Авторизация — неподтверждённый email (сообщение) | `login-unconfirmed-email.png` |
| 6 | Страница регистрации — пустая форма | `register-empty.png` |
| 7 | Регистрация — ошибки валидации (красные рамки) | `register-validation-errors.png` |
| 8 | Регистрация — успех (зелёный баннер) | `register-success-banner.png` |
| 9 | Подтверждение email — редирект на login с toast | `confirmation-success.png` |
| 10 | Подтверждение email — истёкший токен (toast ошибки) | `confirmation-expired-token.png` |

> Скриншоты создаются после того, как все фазы 0–8 завершены и приложение функционирует.

---

## Порядок выполнения (Dependency Graph)

```
Step 0.1 (gems + bundle install)
  ├→ Step 0.2 (redis docker + ENV)
  ├→ Step 0.3 (sidekiq docker)
  ├→ Step 0.4 (active job adapter)
  ├→ Step 0.5 (sidekiq.yml)
  ├→ Step 5.1 (ru.yml)              ← параллельно с инфрой, нет зависимости от БД
  └→ Step 5.2 (default locale)      ← параллельно с инфрой
       │
       └→ Step 1.1 (devise:install)
            └→ Step 1.2 (devise User migration) ⚠️
                 └→ Step 1.3 (model config)
                      └→ Step 1.4 (db:migrate)
                           ├→ Step 2.1 (routes + resend route)
                           ├→ Step 6.1 — 6.2 (mailer config)
                           └→ Step 7.1 — 7.3 (RSpec setup)     ← параллельно с 2.1 и 6.x
                                
                           После 2.1 + 5.x + 6.x:
                           └→ Step 3.1 (ConfirmableLoginHandler concern)
                                └→ Step 3.2 — 3.6 (controllers)
                                     ├→ Step 4.1 — 4.5 (React pages)
                                     └→ (после 7.x тоже завершён):
                                          Step 8.1 — 8.5 (tests)
                                               └→ Step 9.1 (docs)
                                                    └→ Step 10.1 (screenshots)
```

---

## Файлы: полный список изменений

### Изменяемые файлы (edit)

| # | Файл | Фаза |
|---|------|------|
| 1 | `video_chat_and_translator/Gemfile` | 0.1 |
| 2 | `docker/docker-compose.yml` | 0.2, 0.3 |
| 3 | `video_chat_and_translator/config/application.rb` | 0.4, 5.2 |
| 4 | `.env` | 0.2.3 |
| 5 | `video_chat_and_translator/config/routes.rb` | 2.1 |
| 6 | `video_chat_and_translator/app/controllers/application_controller.rb` | 3.6 |
| 7 | `video_chat_and_translator/config/environments/development.rb` | 6.2 |
| 8 | `video_chat_and_translator/app/frontend/pages/Landing.tsx` | 4.5 |

### Создаваемые файлы (create)

| # | Файл | Фаза |
|---|------|------|
| 1 | `video_chat_and_translator/config/sidekiq.yml` | 0.5 |
| 2 | `video_chat_and_translator/config/initializers/devise.rb` | 1.1 (generated) |
| 3 | `video_chat_and_translator/app/models/user.rb` | 1.2 (generated) |
| 4 | `video_chat_and_translator/db/migrate/XXX_devise_create_users.rb` | 1.2 (generated) |
| 5 | `video_chat_and_translator/app/controllers/concerns/confirmable_login_handler.rb` | 3.1 |
| 6 | `video_chat_and_translator/app/controllers/users/sessions_controller.rb` | 3.2 |
| 7 | `video_chat_and_translator/app/controllers/users/registrations_controller.rb` | 3.3 |
| 8 | `video_chat_and_translator/app/controllers/users/confirmations_controller.rb` | 3.4 |
| 9 | `video_chat_and_translator/app/controllers/users/confirmations/resends_controller.rb` | 3.5 |
| 10 | `video_chat_and_translator/app/frontend/pages/auth/AuthLayout.tsx` | 4.1 |
| 11 | `video_chat_and_translator/app/frontend/components/Toast.tsx` | 4.2 |
| 12 | `video_chat_and_translator/app/frontend/pages/auth/Login.tsx` | 4.3 |
| 13 | `video_chat_and_translator/app/frontend/pages/auth/Register.tsx` | 4.4 |
| 14 | `video_chat_and_translator/config/locales/ru.yml` | 5.1 |
| 15 | `video_chat_and_translator/spec/rails_helper.rb` | 7.1 (generated) |
| 16 | `video_chat_and_translator/spec/spec_helper.rb` | 7.1 (generated) |
| 17 | `video_chat_and_translator/spec/factories/users.rb` | 7.3 |
| 18 | `video_chat_and_translator/spec/requests/users/registrations_spec.rb` | 8.1 |
| 19 | `video_chat_and_translator/spec/requests/users/sessions_spec.rb` | 8.2 |
| 20 | `video_chat_and_translator/spec/requests/users/confirmations_spec.rb` | 8.3 |
| 21 | `video_chat_and_translator/spec/requests/users/confirmations/resends_spec.rb` | 8.4 |
| 22 | `video_chat_and_translator/spec/requests/pages_spec.rb` | 8.5 |
| 23 | `video_chat_and_translator/docs/auth-email.md` | 9.1 |
| 24 | `screenshots/001-auth-email/*.png` (10 файлов) | 10.1 |

---

## Контрольные точки (Checkpoints)

| Checkpoint | Критерий прохождения |
|---|---|
| **CP-0** | Docker Compose поднимается: web + db + redis + sidekiq. `bundle exec sidekiq` стартует без ошибок |
| **CP-1** | `rails db:migrate` проходит, `User.create!(email: "test@test.com", password: "12345678")` работает в console |
| **CP-2** | `GET /users/sign_in` рендерит Inertia-страницу Login с переводами. `GET /users/sign_up` рендерит Register с переводами |
| **CP-3** | Регистрация создаёт User, письмо видно в letter_opener_web (`/letter_opener`) |
| **CP-4** | Клик по ссылке из письма подтверждает email, `confirmed_at` заполняется |
| **CP-5** | Авторизация работает: подтверждённый пользователь попадает на главную с toast-уведомлением |
| **CP-6** | Неподтверждённый пользователь не может войти, видит корректное сообщение |
| **CP-7** | Кнопка «Не пришло письмо?» отправляет повторное письмо (AC#5) |
| **CP-8** | `bundle exec rspec` — все тесты зелёные |
| **CP-9** | Скриншоты всех UI-сценариев сохранены в `screenshots/001-auth-email/` (AC#6) |
