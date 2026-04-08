# Feature 004 — Enable hotel creation in admin

## Goal

Add the full create flow for Hotel in the admin panel: `GET /admin/hotels/new`
and `POST /admin/hotels`, with a form object, server-side validation, and role
authorization.

## Context

`Admin::HotelsController` currently has only `#index`. The `Hotel` model has
`name` (required) and `timezone` (required). There are no services or form
objects yet for Hotel. This slice introduces the **create pattern** that slice
005 (edit/delete) will extend.

**Depends on: slice 001 (auth pattern) being complete.**

## Scope

**In:**
- Routes: add `new` and `create` to `resources :hotels` in admin namespace
- `Admin::HotelsController#new` and `#create`
- `Admin::HotelForm` (form object in `app/forms/admin/`) — validates presence
  of `name` and `timezone`
- `Admin::Hotels::CreateService` (service object in `app/services/admin/hotels/`)
  — calls form, persists the record
- View: `app/views/admin/hotels/new.html.erb` with form
- Authorization: only `admin` role may create hotels
- On success: redirect to `admin_hotels_path` with flash
- On failure: re-render `new` with errors
- Request specs: successful create, validation failure, unauthorized role

**Out:**
- Edit/update/destroy (slice 005)
- Hotel-scoped staff or department management
- Client-side validation

## Acceptance Criteria

- [ ] `GET /admin/hotels/new` renders the form for `admin` role
- [ ] `POST /admin/hotels` with valid params creates a Hotel and redirects to index
- [ ] `POST /admin/hotels` with invalid params (missing name or timezone)
  re-renders the form with error messages
- [ ] `manager` and `staff` roles are denied access to both actions
- [ ] No business logic in the controller — delegated to form + service
- [ ] Request specs cover: success, validation failure, unauthorized

## Key Files

| File | Change |
|------|--------|
| `config/routes.rb` | Add `new`, `create` to `resources :hotels` |
| `app/controllers/admin/hotels_controller.rb` | Add `#new`, `#create` |
| `app/forms/admin/hotel_form.rb` | New — form object |
| `app/services/admin/hotels/create_service.rb` | New — create service |
| `app/views/admin/hotels/new.html.erb` | New — form view |
| `spec/requests/admin/hotels_spec.rb` | New — request specs |

## Notes

- Follow the `dry-initializer` pattern for the service object.
- `timezone` input: a plain text field is acceptable for now (no timezone
  picker needed).
- Flash messages should be consistent with any existing flash conventions in
  the admin layout.
- Do not add model-level validations for this slice — keep validation in the
  form object.
