# Project Instructions

See PROJECT.md for project description.

## Stack

- **Backend:** Ruby on Rails 8
- **Frontend:** React with Inertia.js (Monolith architecture)
- **Database:** PostgreSQL
- **Testing:** RSpec, FactoryBot, Webmocks
- **Auth:** Devise, Cancancan
- **Performance:** Bullet (and similar gems to avoid N+1 queries)
- **Environment:** Docker Compose for development
- **Deployment:** Kamal (keys stored in 1Password)

## Environment Details

- All development and testing occur inside Docker containers.
- Standard port 3000 is NOT used; other available free ports are used instead.
- All Docker containers are united under one separate dedicated Docker network.

## Key commands

- `bin/setup` — bootstrap
- `bin/rails s` — run server
- `bundle exec rspec` — run tests
- `bin/rails db:migrate` — migrate

## Core Workflow, Pre-checks & Testing

- **Before implementing new features:** Always review `routes.rb` and `schema.rb` first to understand existing endpoints, models, and fields.
- Subsequently, review existing models, their methods, and controllers. This process is mandatory to avoid code duplication!
- **Testing Requirements:** You MUST write automated tests in parallel with implementing new features.
- **Verification:** Before considering a task complete or submitting work for review, you MUST run the automated test suite to verify that your changes are correct and haven't broken anything.

## Architecture & Conventions

- **Service Objects:** Use *only* for third-party API calls or as independent processors with entirely independent logic (no standard PORO objects for general logic).
- **Concerns:**
  - *Models:* When working with logic for one or more models (where one is the reason for the change), use `concerns` for optimization and logical separation.
  - *Controllers:* Controllers must be clean. If there is logic (like request pre-processing) that cannot be placed in a service object or model according to rules, it should be extracted into a controller `concern`.
- **Controllers & Routing (CRUD strictly):**
  - Controllers must consist solely of standard CRUD actions.
  - **No custom actions** are allowed in standard controllers.
  - If a specific action is needed within a controller's context (e.g., search), create a namespaced controller with the name of that action inside the scope of the main controller.
  - *Example:* If `BlogsController` needs a `search` action, you must create `Blogs::SearchController` with an `index` or `show` action, placing the file in the appropriately scoped directory.
- **Callbacks:**
  - Use callbacks in models and controllers *only* when absolutely justified.
  - In most cases, you should seek alternative solutions (like explicit method calls or processing in separate objects) to ensure the system's execution flow remains clear and predictable.
- **DRY & Documentation:**
  - Strictly adhere to the DRY principle.
  - Any added public methods, classes, modules, and files MUST be documented in a separate document located in the `/docs` path (e.g. `/docs/...`). This ensures any AI agent can read it and understand existing features to avoid duplication.

## Constraints

- **Database Changes:** You MUST ask for permission before modifying the database schema or creating migrations.
- **Gems:** You MUST ask for permission before installing any new gems.
- **Error Handling & Fallbacks:** Avoid excessive error handlers, global rescues, and silent fallbacks. Overusing them hides true errors during development and causes the system to deviate from intended business logic. You MUST consult the user (ask for permission/advice) before implementing complex fallbacks or broad error handling mechanisms.
