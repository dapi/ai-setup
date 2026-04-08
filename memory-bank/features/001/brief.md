# Feature 001 — Secure admin hotel listing by role

## Goal

Replace hardcoded HTTP Basic Auth in the admin panel with Staff-based
authentication so that access to `GET /admin/hotels` depends on the staff
member's role.

## Context

`Admin::BaseController` currently uses `http_basic_authenticate_with` with a
static username/password pair. There is no session, no Staff record lookup, and
no role check. The `Staff` model has `role` enum (`admin: 0`, `manager: 1`,
`staff: 2`) but no password field in the current schema.

This slice establishes the **authentication and authorization pattern** for the
entire admin namespace — slices 002 and 003 replicate it.

## Scope

**In:**
- Add `password_digest` to `Staff` (new migration, `has_secure_password`)
- Implement session-based or HTTP Basic Auth against Staff records in
  `Admin::BaseController`
- Apply role-based access rule to `Admin::HotelsController#index`:
  `admin` and `manager` roles may access; `staff` role is denied
- Update `spec/requests/admin/access_spec.rb` to authenticate via Staff
  credentials instead of hardcoded `"admin"/"password"`
- Add request specs: allowed roles can access, denied roles get 403/redirect

**Out:**
- Staff CRUD (managing staff accounts)
- Password reset / forgot-password flow
- Changes to any controller other than `BaseController` and `HotelsController`
- Securing staff/tickets pages (slices 002–003)

## Acceptance Criteria

- [ ] A Staff record with role `admin` can authenticate and see the hotels list
- [ ] A Staff record with role `manager` can authenticate and see the hotels list
- [ ] A Staff record with role `staff` is denied access (403 or redirect)
- [ ] Unauthenticated request is denied (401 or redirect)
- [ ] Existing `access_spec.rb` is updated and green (not deleted)
- [ ] No hardcoded credentials remain in `BaseController`

## Open Questions

- **Auth mechanism:** session (cookie) vs HTTP Basic Auth against Staff records.
  HTTP Basic against Staff keeps the change small; session-based is more
  realistic. Decide before implementing — the choice affects slices 002–003.
- **Role rule for Hotels:** should `staff` role see a filtered list (own hotel
  only) or be fully denied? Default assumption: fully denied.

## Key Files

| File | Change |
|------|--------|
| `app/controllers/admin/base_controller.rb` | Replace static Basic Auth with Staff auth |
| `app/controllers/admin/hotels_controller.rb` | Add role check |
| `db/migrate/` | New migration: add `password_digest` to `staffs` |
| `app/models/staff.rb` | Add `has_secure_password` |
| `spec/requests/admin/access_spec.rb` | Update + extend |
| `spec/factories/hotels.rb` | May need a staff factory |

## Notes

- This is the **foundation slice** — the auth pattern set here must be
  consistent across 002 and 003.
- `bcrypt` gem is already included in Rails by default; verify it is not
  commented out in `Gemfile` before adding `has_secure_password`.
- Do not modify the existing migration `20260330090000_create_domain_models.rb`.
