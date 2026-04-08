# Feature 002 — Secure admin staff listing by role

## Goal

Apply the authentication and authorization pattern established in slice 001 to
`GET /admin/staff` so that access depends on the staff member's role.

## Context

`Admin::StaffController#index` currently relies on the same hardcoded HTTP Basic
Auth inherited from `BaseController`. After slice 001, `BaseController` will
authenticate against Staff records. This slice adds the **role-based access
rule** specific to the staff listing page.

**Depends on: slice 001 being complete.**

## Scope

**In:**
- Apply role check to `Admin::StaffController#index`:
  `admin` role may access; `manager` and `staff` roles are denied
- Add request specs for allowed/denied roles

**Out:**
- Staff CRUD (create, edit, delete)
- Changes to `BaseController` or authentication mechanism (slice 001 owns that)
- Securing hotels/tickets pages (slices 001, 003)

## Acceptance Criteria

- [ ] Staff with role `admin` can access `GET /admin/staff`
- [ ] Staff with role `manager` is denied (403 or redirect)
- [ ] Staff with role `staff` is denied (403 or redirect)
- [ ] Unauthenticated request is denied
- [ ] Request specs cover all cases above

## Open Questions

- **Role rule:** should `manager` see a filtered staff list (own hotel only)
  rather than being fully denied? Default assumption: `admin` only.
  Confirm before implementing.

## Key Files

| File | Change |
|------|--------|
| `app/controllers/admin/staff_controller.rb` | Add role check |
| `spec/requests/admin/` | New or extended staff access spec |

## Notes

- Reuse the auth helpers and factory setup from slice 001 specs — do not
  duplicate setup logic.
- Role rule here may differ from Hotels (001) — staff listing is more sensitive
  than hotel listing.
