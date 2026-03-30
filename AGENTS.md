See PROJECT.md for project description.

## Stack
Ruby on Rails 7, PostgreSQL, Redis, RSpec, FactoryBot

## Key commands
- `bin/setup` — bootstrap
- `bin/rails s` — run server
- `bundle exec rspec` — run tests
- `bin/rails db:migrate` — migrate
- `bin/rails console` — console

## Conventions
- Thin controllers; business logic in service objects (using `dry-initializer`)
- Prefer one public method per service (`call`)
- Place services in `app/services`, forms in `app/forms`, presenters/serializers in appropriate dirs
- No business logic in views
- Follow Rails naming conventions for classes and files
- Use RuboCop; keep code clean and consistent
- Avoid ActiveRecord callbacks (only when absolutely necessary)
- Prefer validations in service layer; enforce critical constraints at DB level (indexes, null constraints, FKs)
- Patterns in use:
    - Service Objects
    - Presenters / Serializers
    - Form Objects
    - Decorators
- Keep models thin (no fat models)
- Keep methods small and explicit; avoid hidden side effects
- Prefer POROs over complex AR logic where possible
- Write all code, comments, and commit messages in English
- Testing:
    - Do not write model tests
    - Write unit tests for services and core logic
    - Write integration tests for main flows
    - Use FactoryBot for fixtures

## Constraints
- Do NOT change dependencies or update library versions
- Do NOT add new gems without explicit request
- Do NOT modify CI/CD configuration
- Do NOT modify `.env`, secrets, or credentials
- Do NOT perform destructive migrations (no data loss)
- Do NOT change existing migrations
- Do NOT delete existing tests
- Do NOT refactor code outside the scope of the task
- Do NOT change public API contracts or DB schema beyond the task
- Allowed without explicit approval:
    - Create new files
    - Add non-destructive migrations
    - Rename classes/modules when necessary and scoped
    - Add tests for new functionality

