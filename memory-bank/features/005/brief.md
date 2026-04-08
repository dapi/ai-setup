# Feature 005 — Enable hotel editing and deletion in admin

## Goal

Add the full update and delete flow for Hotel in the admin panel: `GET
/admin/hotels/:id/edit`, `PATCH /admin/hotels/:id`, and `DELETE
/admin/hotels/:id`, with a form object, validation, authorization, and
protection against deleting hotels that have associated records.

## Context

After slice 004, Hotel create is in place with `Admin::HotelForm` and
`Admin::Hotels::CreateService`. This slice extends the pattern with update and
destroy. The `Hotel` model has `dependent: :restrict_with_exception` on all
associations — attempting to delete a hotel with guests, staff, departments, or
articles will raise an `ActiveRecord::DeleteRestrictionError`.

**Depends on: slice 004 (create flow, form object) being complete.**

## Scope

**In:**
- Routes: add `edit`, `update`, `destroy` to `resources :hotels`
- `Admin::HotelsController#edit`, `#update`, `#destroy`
- `Admin::Hotels::UpdateService` — wraps form + `hotel.update`
- `Admin::Hotels::DestroyService` — wraps `hotel.destroy`, rescues
  `ActiveRecord::DeleteRestrictionError` and returns a user-friendly error
- Reuse `Admin::HotelForm` from slice 004 (extend if needed)
- Views: `app/views/admin/hotels/edit.html.erb`; delete via button on index or
  edit page (no separate view needed)
- Authorization: only `admin` role may edit or delete
- On update success: redirect to index with flash
- On update failure: re-render `edit` with errors
- On destroy success: redirect to index with flash
- On destroy failure (restricted): redirect back with error flash
- Request specs: successful update, validation failure, successful destroy,
  destroy blocked by associations, unauthorized role

**Out:**
- Bulk delete
- Soft delete / archiving
- Cascading deletes (do not change `dependent:` options on Hotel associations)

## Acceptance Criteria

- [ ] `GET /admin/hotels/:id/edit` renders the edit form for `admin` role
- [ ] `PATCH /admin/hotels/:id` with valid params updates the Hotel and redirects
- [ ] `PATCH /admin/hotels/:id` with invalid params re-renders edit with errors
- [ ] `DELETE /admin/hotels/:id` on a hotel with no associations destroys it
- [ ] `DELETE /admin/hotels/:id` on a hotel with associations fails gracefully
  (no 500 — shows an error flash instead)
- [ ] `manager` and `staff` roles are denied edit and destroy
- [ ] Request specs cover all cases above

## Key Files

| File | Change |
|------|--------|
| `config/routes.rb` | Add `edit`, `update`, `destroy` to `resources :hotels` |
| `app/controllers/admin/hotels_controller.rb` | Add `#edit`, `#update`, `#destroy` |
| `app/forms/admin/hotel_form.rb` | Extend if needed (slice 004 owns creation) |
| `app/services/admin/hotels/update_service.rb` | New |
| `app/services/admin/hotels/destroy_service.rb` | New — handles restriction error |
| `app/views/admin/hotels/edit.html.erb` | New |
| `app/views/admin/hotels/index.html.erb` | Add edit/delete links or buttons |
| `spec/requests/admin/hotels_spec.rb` | Extend from slice 004 |

## Notes

- `restrict_with_exception` raises on destroy — rescue it in `DestroyService`,
  return a failure result, and surface it as a flash error in the controller.
  Do not change the `dependent:` strategy on the model.
- Keep `#find_hotel` as a private `before_action` shared across edit/update/destroy.
- Do not introduce a separate `show` action unless explicitly requested.
