# Current Phase

**Last updated:** 2026-04-11
**Approach:** Vertical slices — each feature delivers end-to-end value (route → controller → auth → view → specs)

---

## Current Epic

**Phase 1 — Core Domain & Admin**

The foundation (Phase 0) is complete. We are now building out the full admin
backoffice CRUD and management UI.

---

## Current Stage

**EPIC 0.3 / 1.1 — Authorization + Hotel Management**

Securing existing read-only pages by role, then extending Hotel with full CRUD.
Five vertical slices defined (see Work Queue below).

---

## What Is Done

### Phase 0 — Foundation (complete)

- **EPIC 0.1** — Rails 7 app, PostgreSQL, Redis, RSpec, FactoryBot, RuboCop
- **EPIC 0.2** — Full domain model migrated and mapped to AR models:
  `Hotel`, `Guest`, `Staff`, `Department`, `Conversation`, `Message`,
  `Ticket`, `KnowledgeBaseArticle` (single migration `20260330090000`)
- **EPIC 0.3** — Admin namespace with HTTP Basic Auth (`admin/base_controller.rb`),
  `layout "admin"`, roles enum on `Staff`; **read-only** index pages for
  hotels, staff, and tickets
- **EPIC 0.4** — `PROJECT.md`, `AGENTS.md`, `CLAUDE.md`, `roadmap.md`

### Phase 1 — partial

| Epic | Status | Notes |
|------|--------|-------|
| 1.1 Hotel Management | started | Auth by role done (feature 001); full CRUD pending |
| 1.2 Staff & Departments | started | `GET /admin/staff` only; no Departments controller |
| 1.3 Ticket Management Core | started | `GET /admin/tickets` only; no CRUD, no status flow |
| 1.4 Knowledge Base Management | not started | no controller / routes |
| 1.5 Messaging Backoffice | not started | no controller / routes |

---

## Work Queue (vertical slices, in order)

| # | Feature | Scope | Status |
|---|---------|-------|--------|
| 1 | [Secure admin hotel listing by role](memory-bank/features/001/brief.md) | Auth rules on `Admin::HotelsController#index` | `done` |
| 2 | [Secure admin staff listing by role](memory-bank/features/002/brief.md) | Auth rules on `Admin::StaffController#index` | `todo` |
| 3 | [Secure admin ticket listing by role](memory-bank/features/003/brief.md) | Auth rules on `Admin::TicketsController#index` | `todo` |
| 4 | [Enable hotel creation in admin](memory-bank/features/004/brief.md) | `new` + `create`, form object, validation, auth | `todo` |
| 5 | [Enable hotel editing and deletion in admin](memory-bank/features/005/brief.md) | `edit`, `update`, `destroy`, auth, request specs | `todo` |

Each slice is independently shippable: route → controller action → authorization
→ view → request specs.

---

## What Is In Progress

Nothing — project is between tasks.

### Recently completed

- **Feature 001 — Secure admin hotel listing by role** (2026-04-11)
  - Replaced hardcoded HTTP Basic Auth with real staff credentials (`has_secure_password`)
  - Added `password_digest` column via migration
  - RBAC: admin/manager → 200, staff → 403, unauthenticated → 401
  - Added FactoryBot factory for `Staff`
  - Added `db/seeds.rb` for all models
  - PR: https://github.com/Melchakovartem/hotel_concierge_bot/pull/2
  - Issue: https://github.com/Melchakovartem/hotel_concierge_bot/issues/1

---

## What Is Blocked

- **Slices 2–5 depend on Slice 1** — ~~authorization pattern must be established
  on Hotels first~~ done; pattern established, replicate to Staff and Tickets next.
- **CRUD slices (4–5) depend on auth slices (1–3)** — do not add write
  endpoints before access control is settled.
- **Departments admin** — no controller yet; not in current queue.
- **Phase 2+ work** depends on Phase 1 CRUD being complete and stable.

---

## Do Not Break

- Single migration `20260330090000_create_domain_models.rb` — **never modify**.
- All eight domain models and their associations.
- Existing admin routes (`/admin/hotels`, `/admin/staff`, `/admin/tickets`).
- RSpec setup (`spec/rails_helper.rb`, `spec/support/`, factories in
  `spec/factories/`).
- `spec/requests/admin/access_spec.rb` — existing auth smoke tests.

---

## Key Files

| Path | Purpose |
|------|---------|
| `roadmap.md` | Full epic breakdown across all phases |
| `PROJECT.md` | Product description (Russian) |
| `AGENTS.md` | AI agent conventions and constraints |
| `db/migrate/20260330090000_create_domain_models.rb` | Canonical schema source |
| `app/controllers/admin/base_controller.rb` | Admin auth + layout |
| `config/routes.rb` | All routes (admin namespace) |
| `spec/requests/admin/access_spec.rb` | Admin auth integration tests |
| `spec/requests/admin/hotels_spec.rb` | Hotels auth + authz request specs |
| `spec/factories/staffs.rb` | FactoryBot factory for Staff |
| `db/seeds.rb` | Seeds for all models |
| `memory-bank/features/001/` | Spec, plan, and brief for feature 001 |
