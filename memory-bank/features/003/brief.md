# Feature 003 — Secure admin ticket listing by role

## Goal

Apply the authentication and authorization pattern established in slice 001 to
`GET /admin/tickets` so that access depends on the staff member's role.

## Context

`Admin::TicketsController#index` currently relies on hardcoded HTTP Basic Auth
inherited from `BaseController`. After slice 001, real Staff-based auth is in
place. This slice adds the **role-based access rule** for the ticket listing and
optionally scopes the data returned based on the viewer's role.

**Depends on: slice 001 being complete.**

## Scope

**In:**
- Apply role check to `Admin::TicketsController#index`:
  `admin` and `manager` roles may access; `staff` role sees only tickets
  assigned to them (or is denied — see Open Questions)
- Add request specs for allowed/denied roles and data scoping

**Out:**
- Ticket CRUD (slice 004+ territory)
- Changes to `BaseController` or auth mechanism
- Securing hotels/staff pages (slices 001–002)

## Acceptance Criteria

- [ ] Staff with role `admin` can access `GET /admin/tickets` and sees all tickets
- [ ] Staff with role `manager` can access `GET /admin/tickets` and sees all tickets
- [ ] Staff with role `staff` — apply decision from Open Questions below
- [ ] Unauthenticated request is denied
- [ ] Request specs cover all role scenarios

## Open Questions

- **`staff` role behavior:** fully denied, or shown only their assigned tickets?
  The `Ticket` model has `staff_id` (nullable). Showing assigned tickets is more
  useful but adds data-scoping logic. Default assumption: fully denied until
  decided.

## Key Files

| File | Change |
|------|--------|
| `app/controllers/admin/tickets_controller.rb` | Add role check (+ optional scoping) |
| `spec/requests/admin/` | New or extended tickets access spec |

## Notes

- If data scoping is chosen for `staff` role, scope via
  `Ticket.where(staff: current_staff)` — keep it in the controller for now,
  extract to a query object if it grows.
- Reuse auth helpers established in slice 001.
