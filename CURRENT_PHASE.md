# Current Phase

**Last updated:** 2026-04-17
**Approach:** Vertical slices — each feature delivers end-to-end value (route → controller → auth → view → specs)
**Current baseline:** `dd84ec6` — Feature 002: Role-based authorization & Hotel CRUD (#4)

---

## Current Epic

**Phase 1 — Core Domain & Admin**

Phase 0 is complete. Phase 1 is in progress: the admin backoffice now has
admin-only access control, full Hotel CRUD, and hotel-scoped read-only views for
staff and tickets.

---

## Current Stage

**EPIC 1.1 complete / EPIC 1.2 and 1.3 partial**

Feature 002 completed the hotel management foundation and tightened the admin
authorization model. The project is currently between tasks. The next work should
continue Phase 1 by turning the remaining read-only admin resources into managed
backoffice workflows.

---

## What Is Done

### Phase 0 — Foundation (complete)

- **EPIC 0.1** — Rails 7 app, PostgreSQL, Redis, RSpec, FactoryBot, RuboCop
- **EPIC 0.2** — Full domain model migrated and mapped to AR models:
  `Hotel`, `Guest`, `Staff`, `Department`, `Conversation`, `Message`,
  `Ticket`, `KnowledgeBaseArticle`
- **EPIC 0.3** — Admin namespace, Basic Auth backed by `Staff` credentials,
  `has_secure_password`, staff roles, admin layout, and admin-only access to
  `/admin/**`
- **EPIC 0.4** — `PROJECT.md`, `AGENTS.md`, `CLAUDE.md`, `roadmap.md`

### Phase 1 — progress

| Epic | Status | Notes |
|------|--------|-------|
| 1.1 Hotel Management | complete | Full admin CRUD, slug routes, validation errors, delete restriction handling |
| 1.2 Staff & Departments | partial | Global `GET /admin/staff`; hotel-scoped staff index/show; no staff CRUD; no Departments controller |
| 1.3 Ticket Management Core | partial | Global `GET /admin/tickets`; hotel-scoped ticket index; `tickets.hotel_id`, `subject`, `body`; no ticket CRUD/status workflow |
| 1.4 Knowledge Base Management | not started | no controller / routes |
| 1.5 Messaging Backoffice | not started | no conversations/messages admin controller / routes |

---

## Recently Completed

### Feature 001 — Secure admin hotel listing by role

- Replaced hardcoded HTTP Basic Auth with real staff credentials
- Added `password_digest` to `staffs`
- Established the request auth helper and baseline admin access specs
- PR: https://github.com/Melchakovartem/hotel_concierge_bot/pull/2
- Issue: https://github.com/Melchakovartem/hotel_concierge_bot/issues/1

### Feature 002 — Role-based authorization & Hotel CRUD

- Restricted the entire `/admin/**` namespace to `admin` role only
  - unauthenticated users receive `401`
  - `manager` and `staff` receive `302` redirect to `/`
- Added `BaseService` and `Result` service infrastructure
- Added `Hotel#slug`, unique `hotels.name`, and slug-based hotel routes
- Implemented full Hotel CRUD in `Admin::HotelsController`
- Added service objects:
  - `Admin::Hotels::CreateService`
  - `Admin::Hotels::UpdateService`
  - `Admin::Hotels::DestroyService`
  - `Admin::Hotels::SlugGenerator`
  - `Admin::Hotels::TicketsQuery`
- Added direct hotel ownership to tickets via `tickets.hotel_id`
- Added `tickets.subject` and `tickets.body`
- Added ticket validation that associated guest, department, and staff belong to
  the same hotel as the ticket
- Added hotel-scoped read-only resources:
  - `GET /admin/hotels/:hotel_slug/staff`
  - `GET /admin/hotels/:hotel_slug/staff/:id`
  - `GET /admin/hotels/:hotel_slug/tickets`
- Added admin views, shared error partial, flash rendering, i18n entries, updated
  factories, and request/service specs for the new behavior
- PR: https://github.com/Melchakovartem/hotel_concierge_bot/pull/4
- Issue: https://github.com/Melchakovartem/hotel_concierge_bot/issues/3

---

## What Is In Progress

Nothing — project is between tasks.

---

## Suggested Next Work Queue

No feature specs exist yet after `memory-bank/features/002/`. Create a new spec
and plan before implementation.

| # | Candidate feature | Roadmap scope | Status |
|---|-------------------|---------------|--------|
| 3 | Staff and Department management | EPIC 1.2 | spec needed |
| 4 | Ticket management core | EPIC 1.3 | spec needed |
| 5 | Knowledge Base management | EPIC 1.4 | spec needed |
| 6 | Messaging backoffice | EPIC 1.5 | spec needed |

Recommended next slice: **EPIC 1.2 — Staff & Departments**, because tickets
already depend on departments and staff assignment.

---

## What Is Blocked / Deferred

- **Manager/staff namespaces** — explicitly outside Feature 002 scope; admin
  remains admin-only until role-specific sections are designed.
- **Staff CRUD and Department CRUD** — not implemented yet; only read paths exist.
- **Ticket CRUD/status workflow/history/assignment UI** — not implemented yet;
  ticket data model was strengthened, but admin ticket management remains
  read-only.
- **Phase 2+ Guest Communication MVP** — depends on Phase 1 CRUD and backoffice
  workflows being stable enough to support guest-facing communication.

---

## Do Not Break

- Historical migrations, especially `20260330090000_create_domain_models.rb` —
  never modify existing migrations.
- Admin auth behavior:
  - missing/invalid Basic Auth → `401` with `WWW-Authenticate`
  - authenticated non-admin (`manager`, `staff`) → `302` to `/`
  - admin → allowed through `/admin/**`
- Slug-based hotel routing: `resources :hotels, param: :slug`
- `Hotel#to_param` returning `slug`
- `Hotel.slug` generation via `Admin::Hotels::SlugGenerator`
- Hotel deletion restrictions for associated `guests`, `staff`, `departments`,
  `tickets`, and `knowledge_base_articles`
- Ticket hotel consistency validation across `guest`, `department`, and optional
  `staff`
- Existing admin routes:
  - `/admin/hotels`
  - `/admin/hotels/:slug`
  - `/admin/hotels/:hotel_slug/staff`
  - `/admin/hotels/:hotel_slug/tickets`
  - `/admin/staff`
  - `/admin/tickets`
- RSpec setup, request auth helpers, and FactoryBot factories.

---

## Key Files

| Path | Purpose |
|------|---------|
| `roadmap.md` | Full epic breakdown across all phases |
| `PROJECT.md` | Product description |
| `AGENTS.md` | Agent conventions and project constraints |
| `memory-bank/features/001/` | Spec, plan, and brief for Feature 001 |
| `memory-bank/features/002/` | Spec, plan, and brief for Feature 002 |
| `config/routes.rb` | Admin routes, slug-based Hotel CRUD, nested hotel resources |
| `app/controllers/admin/base_controller.rb` | Admin authentication, admin-only authorization, shared 404 handling |
| `app/controllers/admin/hotels_controller.rb` | Hotel CRUD |
| `app/controllers/admin/hotel_staff_controller.rb` | Hotel-scoped staff read-only views |
| `app/controllers/admin/hotel_tickets_controller.rb` | Hotel-scoped ticket read-only view |
| `app/models/hotel.rb` | Hotel associations, validations, slug URL param |
| `app/models/ticket.rb` | Ticket hotel ownership and consistency validation |
| `app/services/base_service.rb` | Service object base contract |
| `app/services/result.rb` | Service result value object |
| `app/services/admin/hotels/` | Hotel create/update/destroy/slug/query services |
| `app/views/admin/hotels/` | Hotel admin views |
| `app/views/admin/hotel_staff/` | Hotel-scoped staff views |
| `app/views/admin/hotel_tickets/` | Hotel-scoped ticket views |
| `app/views/shared/_errors.html.erb` | Shared validation error partial |
| `spec/requests/admin/access_spec.rb` | Admin access integration tests |
| `spec/requests/admin/hotels_spec.rb` | Hotel CRUD and authorization request specs |
| `spec/requests/admin/hotel_staff_spec.rb` | Hotel staff request specs |
| `spec/requests/admin/hotel_tickets_spec.rb` | Hotel tickets request specs |
| `spec/services/admin/hotels/` | Hotel service specs |
