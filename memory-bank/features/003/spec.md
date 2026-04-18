# Спецификация — Feature 003: staff ticket workflow без admin

**Brief:** memory-bank/features/003/brief.md

## 1. Цель

Операционные роли проходят обработку тикета без `admin`:

1. `manager` создает пользователя `staff` для своего отеля.
2. `manager` назначает существующий тикет этого отеля этому пользователю `staff`.
3. Назначенный `staff` видит тикет.
4. Назначенный `staff` переводит тикет из `new` в `in_progress`.
5. Назначенный `staff` переводит тикет из `in_progress` в `done`.

Success: request spec проходит сценарий с credentials `manager` и `staff`.

## 2. Объем работ

Входит:

- Server-rendered namespace `/operations/**` для `manager` и `staff`.
- HTTP Basic authentication для operations с realm `Operations`.
- Создание staff-пользователей manager-ом для своего отеля.
- Список, просмотр, назначение, переназначение, снятие назначения и обновление статуса тикетов manager-ом внутри своего отеля.
- Список и просмотр тикетов staff-пользователем для лично назначенных тикетов или тикетов того же department.
- Действия `start` и `complete` для staff по лично назначенным тикетам.
- Non-destructive migration для `staffs.department_id`, unique index `staffs.email` и DB check для `staffs.department_id`.
- Service/query objects и specs.

Не входит:

- Универсальный RBAC/ACL framework.
- Audit log, notifications, SLA tracking и bulk ticket actions.
- Guest-facing ticket creation.
- JSON API.
- Login/logout screens или session-based authentication.
- Новые ticket statuses или изменение названий существующих статусов.
- Изменения публичных контрактов `/admin/**`, кроме сохранения admin-only доступа.

Только 3 области:

- Routing, controllers, views и layout для operations.
- Service/query objects для staff/ticket из раздела 6.
- Инварианты данных staff через migration, model validation и factories.

## 3. Routes и роли

Operations workflow НЕ ДОЛЖНЫ использовать `/admin/**`.

| Method | Path | Controller#Action | Roles |
|---|---|---|---|
| GET | `/operations` | redirect to `/operations/tickets` | manager, staff |
| GET | `/operations/staff` | `operations/staff#index` | manager |
| GET | `/operations/staff/new` | `operations/staff#new` | manager |
| POST | `/operations/staff` | `operations/staff#create` | manager |
| GET | `/operations/tickets` | `operations/tickets#index` | manager, staff |
| GET | `/operations/tickets/:id` | `operations/tickets#show` | manager, staff |
| GET | `/operations/tickets/:id/edit` | `operations/tickets#edit` | manager |
| PATCH | `/operations/tickets/:id` | `operations/tickets#update` | manager |
| PATCH | `/operations/tickets/:id/start` | `operations/tickets#start` | assigned staff |
| PATCH | `/operations/tickets/:id/complete` | `operations/tickets#complete` | assigned staff |

Views: layout содержит tickets-nav и staff-nav только для `manager`; ticket table: `id`, `status`, `department`, `staff`; staff table: `name`, `email`, `department`; forms содержат только service whitelisted params; flash: `Staff created` для create, `Ticket updated` для update/start/complete; validation summary выводит `result.messages`.

## 4. Auth и состояния

Создать `Operations::BaseController`.

Аутентификация:

- Реализовать HTTP Basic authentication тем же алгоритмом, что `Admin::BaseController`, но с `WWW-Authenticate: Basic realm="Operations"`.
- При отсутствующих или невалидных credentials возвращать `401 Unauthorized` с `WWW-Authenticate: Basic realm="Operations"`.
- Аутентифицированный пользователь сохраняется в `@current_staff`.

Авторизация:

- `admin`: нет доступа к `/operations/**`; возвращать `403 Forbidden`.
- `manager`: разрешены manager actions и ticket read/update своего отеля.
- `staff`: разрешены read actions для видимых тикетов; `start` и `complete` только для лично назначенных тикетов.
- Запрещенные комбинации role/action возвращают `403 Forbidden`.
- Records вне `@current_staff.hotel` возвращают `404 Not Found`.

Состояния UI и ошибки:

- Loading: не реализуется, потому что все operations pages являются synchronous server-rendered pages.
- Empty: `/operations/tickets` показывает `No tickets found`; `/operations/staff` показывает `No staff found`.
- Success: staff create redirect на `/operations/staff`; ticket update, `start` и `complete` redirect на `/operations/tickets/:id`; каждое успешное действие показывает success flash.
- Validation error: невалидные create/update/start/complete возвращают `422 Unprocessable Entity`, рендерят ту же template, выводят `result.messages` и не меняют attributes вне whitelist.
- Authentication error: `401` с operations Basic Auth realm.
- Authorization error: `403 Forbidden`.
- Scope error: `404 Not Found`.

## 5. Данные и инварианты

Миграция:

```ruby
add_reference :staffs, :department, null: true, foreign_key: true
add_index :staffs, :email, unique: true
add_check_constraint :staffs,
                     "role != 2 OR department_id IS NOT NULL", # 2 = Staff.roles[:staff]
                     name: "staff_role_requires_department"
```

Изменения моделей:

- `Staff` добавляет `belongs_to :department, optional: true`.
- `Staff` валидирует presence для `name` и `email`.
- `Staff` валидирует uniqueness для `email`.
- `Staff` валидирует presence для `department`, когда `role == "staff"`.
- `Staff` валидирует `department.hotel_id == hotel_id`, когда department присутствует.
- `Ticket` не меняет associations, status enum и существующие validations.

Инварианты:

- Каждый operations query scoped by `@current_staff.hotel`.
- Cross-hotel data никогда не видны, не назначаемы и не изменяемы.
- Роль `staff` принадлежит ровно одному department в том же отеле.
- Роли `admin` и `manager` не требуют department.
- Email staff-пользователя глобально уникален.
- Пользователи, созданные manager-ом, всегда получают `hotel: manager.hotel` и `role: :staff`.
- Role никогда не принимается из operations staff creation params.
- Manager ticket updates меняют только `staff_id` и `status`.
- Staff может изменять только лично назначенные тикеты.
- `start` разрешен только для тикетов в статусе `new` и меняет status на `in_progress`.
- `complete` разрешен только для тикетов в статусе `in_progress` и меняет status на `done`.

## 6. Services и queries

Каждый service/query object имеет один public method: `call`. Controllers выполняют только authentication, authorization, record lookup, service/query call и response rendering/redirect.

- `Operations::Staff::CreateService`
  - options: `manager`, `params`
  - создает `Staff` с `hotel: manager.hotel`, `role: :staff`
  - принимает только `name`, `email`, `password`, `password_confirmation`, `department_id`
  - отклоняет duplicate email и cross-hotel department
  - возвращает `Result` через `BaseService#success`/`#failure`
- `Operations::Tickets::ManagerUpdateService`
  - options: `manager`, `ticket`, `params`
  - проверяет hotel scope тикета
  - принимает только `staff_id` и `status`
  - разрешает blank `staff_id`, чтобы снять назначение
  - отклоняет cross-hotel staff и non-staff assignees
  - принимает только существующие enum statuses: `new`, `in_progress`, `done`, `canceled`
  - возвращает `Result` через `BaseService#success`/`#failure`
- `Operations::Tickets::VisibleTicketsQuery`
  - options: `staff`
  - manager: все тикеты своего отеля
  - staff: тикеты своего отеля, где `ticket.staff_id == staff.id` OR `ticket.department_id == staff.department_id`
  - admin: нет records
- `Operations::Tickets::StartService`
  - options: `staff`, `ticket`
  - требует role `staff`, same hotel, personal assignment и status `new`
  - при успехе: устанавливает status `in_progress`, возвращает `Result` через `BaseService#success`
  - при ошибке: возвращает `Result` через `BaseService#failure` с `messages`
- `Operations::Tickets::CompleteService`
  - options: `staff`, `ticket`
  - требует role `staff`, same hotel, personal assignment и status `in_progress`
  - при успехе: устанавливает status `done`, возвращает `Result` через `BaseService#success`
  - при ошибке: возвращает `Result` через `BaseService#failure` с `messages`

## 7. Критерии приемки

- `/admin/**` остается доступным только для `admin`.
- `/operations/**` доступен `manager` и `staff` только по таблице маршрутов и правилам авторизации из разделов 3-4.
- Отсутствующие или невалидные operations credentials возвращают `401` с operations realm.
- Запрещенные operations actions возвращают `403`.
- Cross-hotel record access возвращает `404`.
- Manager может создавать `staff` users только для своего отеля.
- Новые `staff` users принадлежат ровно одному department в том же отеле.
- Manager видит все тикеты своего отеля.
- Manager может назначать, переназначать, снимать назначение и обновлять status своих тикетов.
- Manager не может менять `guest_id`, `hotel_id`, `department_id`, `subject`, `body` или `priority`.
- Manager assignment select содержит только `staff` users своего отеля.
- Department select содержит только departments своего отеля.
- Staff видит тикеты своего отеля, назначенные лично ему или принадлежащие тому же department.
- Staff не может открывать manager edit/update или staff-management endpoints.
- Staff может брать в работу только лично назначенные тикеты в статусе `new`.
- Staff может завершать только лично назначенные тикеты в статусе `in_progress`.
- Staff не может завершить тикет напрямую из `new`.
- Staff не может взять в работу тикет в статусе `done` или `canceled`.
- Same-department visibility не дает права менять status.
- Ни один operations scenario не требует `admin`.
- Один end-to-end request spec проходит workflow с credentials `manager` и `staff` и проверяет cross-hotel denial.

## 8. Обязательные тесты

- Request specs для authentication failures и role access matrix.
- Regression request spec: `/admin/**` остается admin-only.
- Service specs для staff create, duplicate email и cross-hotel department denial.
- Request specs для staff create, validation failure, staff-management denial для staff и cross-hotel department denial.
- Service specs для assignment, reassignment, unassignment, status update, cross-hotel staff denial и disallowed attributes.
- Request specs для manager ticket list/show/edit/update и cross-hotel ticket denial.
- Query specs для manager visibility, staff assigned visibility, staff same-department visibility, unrelated department exclusion и cross-hotel exclusion.
- Request specs для `staff` role ticket index/show visibility и edit/update denial.
- Service specs для `new` -> `in_progress`, `in_progress` -> `done`, unassigned ticket denial, same-department unassigned denial и invalid transition denial.
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
  9. Manager из другого отеля получает `404` при попытке доступа к тикету.
  10. Staff из другого отеля получает `404` при попытке доступа к тикету.

## 9. Ограничения реализации

- Не добавлять и не обновлять gems.
- Не изменять существующие migrations.
- Не выполнять destructive migrations.
- Views не изменяют records и не выбирают workflow branch.
- Controllers не меняют ticket/staff state напрямую; они вызывают service/query objects.
- Model logic ограничен validations и associations из раздела 5.
- Сохранить существующие ticket status names и admin behavior.
- Использовать FactoryBot для fixtures.
- Не писать model specs; покрывать services, queries и request flows.
