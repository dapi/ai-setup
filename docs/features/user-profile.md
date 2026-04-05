# User Profile Feature (003)

Allows authenticated users to view their profile and change their email address or password.

---

## Routes

| HTTP   | Path                      | Controller#Action                        |
|:-------|:--------------------------|:-----------------------------------------|
| GET    | `/users/profile`          | `users/profile#show`                     |
| PATCH  | `/users/profile/email`    | `users/profile/emails#update`            |
| PATCH  | `/users/profile/password` | `users/profile/passwords#update`         |

All routes require authentication (`authenticate_user!` from `ApplicationController`).

---

## Controllers

### `Users::ProfileController` (`app/controllers/users/profile_controller.rb`)

- `show` — Renders the `profile/Show` Inertia page with i18n translations.
- `current_user` email and `unconfirmed_email` arrive via shared props set in `ApplicationController`.

### `Users::Profile::EmailsController` (`app/controllers/users/profile/emails_controller.rb`)

- `update` — Changes the user's email address.
  - If the new email equals the current email → renders `profile/Show` with `errors: { email: [...] }`.
  - If `current_user.update(email: ...)` succeeds → redirects to `/users/profile` with flash notice.
    - Because `config.reconfirmable = true`, Devise stores the new email in `unconfirmed_email` and sends a confirmation email to the new address. The old email stays active until confirmed.
  - On validation failure → renders `profile/Show` with `errors: current_user.errors.messages`.

### `Users::Profile::PasswordsController` (`app/controllers/users/profile/passwords_controller.rb`)

- `update` — Changes the user's password using Devise's `update_with_password`.
  - Verifies the current password before updating.
  - On success → `bypass_sign_in` keeps the session alive, redirects with flash notice.
  - On failure → renders `profile/Show` with `errors`.

---

## Frontend

### `app/frontend/pages/profile/Show.tsx`

Single-page profile component using `AuthLayout`. Contains two independent forms:

1. **Email form** — `PATCH /users/profile/email`
   - Shows current email and pending `unconfirmed_email` (if any).
   - Field for new email + submit button.

2. **Password form** — `PATCH /users/profile/password`
   - Fields: current password, new password, confirmation.
   - Link to `/users/password/new` ("Забыли пароль?").

Both forms use `useForm` from `@inertiajs/react`. Validation errors render inline (red border + message).

### `app/frontend/pages/Landing.tsx`

Added a "Профиль" `<Link>` button next to the "Выйти" button for authenticated users.

---

## i18n Keys (`config/locales/ru.yml`)

Section `auth.profile`:
- `title`, `link`, `back_to_home`
- `email.section_title`, `email.current_email_label`, `email.new_email_label`, `email.new_email_placeholder`, `email.submit`, `email.success`, `email.pending_confirmation`, `email.same_as_current`
- `password.section_title`, `password.current_password_label`, `password.current_password_placeholder`, `password.new_password_label`, `password.new_password_placeholder`, `password.password_confirmation_label`, `password.password_confirmation_placeholder`, `password.submit`, `password.success`, `password.forgot_password`

---

## Configuration Changes

| File | Change |
|:-----|:-------|
| `config/initializers/devise.rb` | `reconfirmable = true` (email change requires confirmation) |
| `config/initializers/devise.rb` | `password_length = 8..128` (aligned with i18n "минимум 8 символов") |
| `app/controllers/application_controller.rb` | `allow_browser` skipped in test env; `unconfirmed_email` added to shared props |
| `config/environments/test.rb` | `config.host_authorization` exclusion added; see also rails_helper.rb fix |
| `spec/rails_helper.rb` | `ENV['RAILS_ENV'] = 'test'` (hard-assign instead of `||=`) to prevent dev env leaking in |

---

## Tests

- `spec/requests/users/profile_spec.rb` — GET `/users/profile`
- `spec/requests/users/profile/emails_spec.rb` — PATCH `/users/profile/email`
- `spec/requests/users/profile/passwords_spec.rb` — PATCH `/users/profile/password`

---

## Related Features

- **001 — Auth** (registration, login, confirmation)
- **002 — Forgot Password** (password reset via email)
