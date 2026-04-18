# Спецификация — Feature 003: обработка тикетов персоналом отеля без участия admin

**Brief:** memory-bank/features/003/brief.md

## 1. Цель

Дать операционным ролям отеля возможность пройти процесс обработки тикета без `admin`:

1. `manager` создает пользователя `staff` для своего отеля.
2. `manager` назначает существующий тикет этого отеля этому пользователю `staff`.
3. Назначенный `staff` видит тикет.
4. Назначенный `staff` переводит тикет из `new` в `in_progress`.
5. Назначенный `staff` переводит тикет из `in_progress` в `done`.

Фича считается успешной, когда один request spec проходит этот сценарий только с учетными данными ролей `manager` и `staff`.

## 2. Объем работ

Входит в объем работ:

- Новый server-rendered namespace `/operations/**` для `manager` и `staff`.
- HTTP Basic authentication для operations по паттерну `Admin::BaseController`.
- Создание staff-пользователей manager-ом для отеля manager-а.
- Список, просмотр, назначение, переназначение, снятие назначения и обновление статуса тикетов manager-ом внутри отеля manager-а.
- Список и просмотр тикетов staff-пользователем для лично назначенных тикетов или тикетов того же department внутри отеля staff-пользователя.
- Действия `start` и `complete` для staff по лично назначенным тикетам.
- Non-destructive migration для `staffs.department_id`, unique index для `staffs.email` и DB check, требующий `department_id` для роли `staff`.
- Service objects, query objects и request specs для процесса обработки.

Не входит в объем работ:

- Универсальный RBAC/ACL framework.
- Audit log, notifications, SLA tracking и bulk ticket actions.
- Guest-facing ticket creation.
- JSON API.
- Login/logout screens или session-based authentication.
- Новые ticket statuses или изменение названий существующих статусов.
- Изменения публичных контрактов `/admin/**`, кроме сохранения admin-only доступа.

Области реализации ограничены:

- Routing, controllers, views и layout для operations.
- Service objects и query objects для staff/ticket со спецификациями, перечисленными ниже.
- Инварианты данных staff через migration, model validation и factories.

## 3. Маршруты и роли

Операционные workflow НЕ ДОЛЖНЫ использовать `/admin/**`.

```ruby
namespace :operations do
  root "tickets#index"

  resources :staff, only: %i[index new create]
  resources :tickets, only: %i[index show edit update] do
    member do
      patch :start
      patch :complete
    end
  end
end
```

| Method | Path | Controller#Action | Roles |
|---|---|---|---|
| GET | `/operations` | `operations/tickets#index` | manager, staff |
| GET | `/operations/staff` | `operations/staff#index` | manager |
| GET | `/operations/staff/new` | `operations/staff#new` | manager |
| POST | `/operations/staff` | `operations/staff#create` | manager |
| GET | `/operations/tickets` | `operations/tickets#index` | manager, staff |
| GET | `/operations/tickets/:id` | `operations/tickets#show` | manager, staff |
| GET | `/operations/tickets/:id/edit` | `operations/tickets#edit` | manager |
| PATCH | `/operations/tickets/:id` | `operations/tickets#update` | manager |
| PATCH | `/operations/tickets/:id/start` | `operations/tickets#start` | assigned staff |
| PATCH | `/operations/tickets/:id/complete` | `operations/tickets#complete` | assigned staff |

Views используют такое же расположение навигации, table markup, form field markup, flash rendering и pattern summary ошибок, как текущий admin UI.

## 4. Аутентификация, авторизация и состояния

Создать `Operations::BaseController`.

Аутентификация:

- Переиспользовать стиль HTTP Basic authentication из `Admin::BaseController`.
- При отсутствующих или невалидных учетных данных возвращать `401 Unauthorized` с `WWW-Authenticate: Basic realm="Operations"`.
- Аутентифицированный пользователь сохраняется в `@current_staff`.

Авторизация:

- `admin`: нет доступа к `/operations/**`; возвращать `403 Forbidden`.
- `manager`: разрешены manager actions и ticket read/update actions внутри отеля manager-а.
- `staff`: разрешены read actions для видимых тикетов; `start` и `complete` только для лично назначенных тикетов.
- Запрещенные комбинации role/action возвращают `403 Forbidden`.
- Records вне `@current_staff.hotel` возвращают `404 Not Found`.

Состояния UI и ошибки:

- Loading: не реализуется, потому что все operations pages являются synchronous server-rendered pages.
- Empty: `/operations/tickets` показывает `No tickets found`; `/operations/staff` показывает `No staff found`.
- Success: staff create делает redirect на `/operations/staff`; ticket update, `start` и `complete` делают redirect на `/operations/tickets/:id`; каждое успешное действие показывает success flash.
- Validation error: невалидные create/update/start/complete возвращают `422 Unprocessable Entity`, рендерят ту же page или form, показывают errors и не меняют disallowed attributes.
- Authentication error: `401` с operations Basic Auth realm.
- Authorization error: `403 Forbidden`.
- Scope error: `404 Not Found`.

## 5. Изменения данных и инварианты

Миграция:

```ruby
add_reference :staffs, :department, null: true, foreign_key: true
add_index :staffs, :email, unique: true
add_check_constraint :staffs,
                     "role != 2 OR department_id IS NOT NULL",
                     name: "staff_role_requires_department"
```

Изменения моделей:

- `Staff` добавляет `belongs_to :department, optional: true`.
- `Staff` валидирует presence для `name` и `email`.
- `Staff` валидирует uniqueness для `email`.
- `Staff` валидирует presence для `department`, когда `role == "staff"`.
- `Staff` валидирует `department.hotel_id == hotel_id`, когда department присутствует.
- `Ticket` сохраняет текущие associations, status enum и same-hotel validation для связанных records.

Инварианты:

- Каждый operations query scoped через `@current_staff.hotel`.
- Cross-hotel data никогда не видны, не назначаемы и не изменяемы.
- Роль `staff` принадлежит ровно одному department в том же отеле.
- Роли `admin` и `manager` не требуют department.
- Email staff-пользователя глобально уникален.
- Пользователи, созданные manager-ом, всегда получают `hotel: manager.hotel` и `role: :staff`.
- Role никогда не принимается из operations staff creation params.
- Manager ticket updates могут менять только `staff_id` и `status`.
- Staff может изменять только лично назначенные тикеты.
- `start` разрешен только для тикетов в статусе `new` и меняет status на `in_progress`.
- `complete` разрешен только для тикетов в статусе `in_progress` и меняет status на `done`.

## 6. Service objects и query objects

Использовать один public method, `call`, и держать controllers thin.

- `Operations::Staff::CreateService`
  - options: `manager`, `params`
  - создает `Staff` с `hotel: manager.hotel`, `role: :staff`
  - принимает только `name`, `email`, `password`, `password_confirmation`, `department_id`
  - отклоняет duplicate email и cross-hotel department
  - возвращает существующий `Result` object
- `Operations::Tickets::ManagerUpdateService`
  - options: `manager`, `ticket`, `params`
  - проверяет hotel scope тикета
  - принимает только `staff_id` и `status`
  - разрешает blank `staff_id`, чтобы снять назначение
  - отклоняет cross-hotel staff и non-staff assignees
  - принимает только существующие enum statuses: `new`, `in_progress`, `done`, `canceled`
  - возвращает существующий `Result` object
- `Operations::Tickets::VisibleTicketsQuery`
  - options: `staff`
  - manager: все тикеты в отеле manager-а
  - staff: тикеты в отеле staff-пользователя, где `ticket.staff_id == staff.id` OR `ticket.department_id == staff.department_id`
  - admin: нет records
- `Operations::Tickets::StartService`
  - options: `staff`, `ticket`
  - требует role `staff`, same hotel, personal assignment и status `new`
- `Operations::Tickets::CompleteService`
  - options: `staff`, `ticket`
  - требует role `staff`, same hotel, personal assignment и status `in_progress`

## 7. Критерии приемки

- `/admin/**` остается доступным только для `admin`.
- `/operations/**` доступен аутентифицированным пользователям `manager` и `staff` согласно правилам ролей выше.
- Отсутствующие или невалидные operations credentials возвращают `401` с operations realm.
- Запрещенные operations actions возвращают `403`.
- Cross-hotel record access возвращает `404`.
- Manager может создавать `staff` users только для отеля manager-а.
- Новые `staff` users принадлежат ровно одному department в том же отеле.
- Manager видит все тикеты отеля manager-а.
- Manager может назначать, переназначать, снимать назначение и обновлять status тикетов отеля manager-а.
- Manager не может менять `guest_id`, `hotel_id`, `department_id`, `subject`, `body` или `priority`.
- Manager assignment select содержит только `staff` users из отеля manager-а.
- Department select содержит только departments из отеля manager-а.
- Staff видит тикеты из отеля staff-пользователя, которые назначены лично ему или принадлежат тому же department.
- Staff не может открывать manager edit/update или staff-management endpoints.
- Staff может брать в работу только лично назначенные тикеты в статусе `new`.
- Staff может завершать только лично назначенные тикеты в статусе `in_progress`.
- Staff не может завершить тикет напрямую из `new`.
- Staff не может взять в работу тикет в статусе `done` или `canceled`.
- Same-department visibility не дает права менять status.
- Ни один operations scenario не требует `admin`.
- Один end-to-end request spec проходит полный workflow только с credentials ролей `manager` и `staff` и проверяет cross-hotel denial.

## 8. Обязательные тесты

- Request specs для operations authentication failures и role access matrix.
- Regression request spec, доказывающий, что `/admin/**` остается admin-only.
- Service specs для успешного создания staff, duplicate email и отклонения cross-hotel department.
- Request specs для успешного создания staff manager-ом, validation failure, запрета staff-management pages для staff и отклонения cross-hotel department.
- Service specs для manager assignment, reassignment, unassignment, status update, отклонения cross-hotel staff и disallowed attributes.
- Request specs для manager ticket list/show/edit/update и cross-hotel ticket denial.
- Query specs для manager visibility, staff assigned visibility, staff same-department visibility, исключения unrelated department и исключения cross-hotel.
- Request specs, доказывающие staff list/show visibility и edit/update denial.
- Service specs для `new` -> `in_progress`, `in_progress` -> `done`, отклонения unassigned ticket, отклонения same-department unassigned ticket и отклонения invalid transition.
- Request specs для `start` и `complete` buttons/actions.
- End-to-end request spec:
  1. В системе существуют hotel, manager, department, guest и тикет в статусе `new`.
  2. Manager создает same-hotel `staff` user с department.
  3. Manager назначает тикет этому staff user.
  4. Staff аутентифицируется и видит тикет.
  5. Staff берет тикет в работу.
  6. Staff завершает тикет.
  7. Ticket status равен `done`.
  8. Spec никогда не аутентифицируется как `admin`.
  9. Manager/staff из другого отеля не могут получить доступ к тикету.

## 9. Ограничения реализации

- Не добавлять и не обновлять gems.
- Не изменять существующие migrations.
- Не выполнять destructive migrations.
- Не добавлять business workflow logic во views.
- Держать controllers thin; workflow decisions размещать в service/query objects.
- Ограничить model logic data invariants.
- Сохранить существующие ticket status names и admin behavior.
- Использовать FactoryBot для fixtures.
- Не писать model specs; покрывать services, queries и request flows.
