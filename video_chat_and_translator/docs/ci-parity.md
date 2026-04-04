# CI vs Dev Environment Parity

This document describes differences between the CI Docker environment and the local development environment.

## Compose files

CI uses a **standalone** compose file, separate from the dev one:

```
docker/docker-compose.yml        # dev
docker/docker-compose.ci.yml     # CI (standalone)
```

### Why standalone (not an override)?

Docker Compose v2 **merges** `environment` variables by key and does **not** clear
`volumes` with `volumes: []`. A two-file override (`-f base -f override`) would inherit
dev bind mounts and env vars (`VITE_RUBY_HOST`, `PORT`, `BINDING`), breaking CI isolation.

A standalone file gives full control over what's in the CI container.

## Differences table

| Setting | Dev (`docker-compose.yml`) | CI (`docker-compose.ci.yml`) | Reason |
|---|---|---|---|
| `RAILS_ENV` | `development` | `test` | Run checks in test environment |
| `DATABASE_URL` | `…/video_chat_and_translator_development` | `…/video_chat_and_translator_test` | Separate test database |
| `volumes` | Host mount + bundle/node_modules cache | None (code via `COPY` in image) | No host mount needed in CI |
| `VITE_RUBY_HOST` | `0.0.0.0` | **absent** | Not needed for static checks |
| `PORT` | `3100` | **absent** | No server started in CI |
| `BINDING` | `0.0.0.0` | **absent** | No server started in CI |
| `stdin_open` / `tty` | `true` | `false` | Non-interactive CI runner; `tty: true` can cause hangs |
| `networks` | `video_chat_network` (bridge) | Default compose network | CI services don't need the dev network |
| `ports` | `3100:3100`, `3036:3036`, `5432` | None | No exposed ports needed in CI |

## Database

| | Dev | CI |
|---|---|---|
| Database name | `video_chat_and_translator_development` | `video_chat_and_translator_test` |
| User | `postgres` | `postgres` |
| Password | `postgres` | `postgres` |
| Host | `db` (Docker service) | `db` (Docker service) |

## References

- [`docker/docker-compose.ci.yml`](../../docker/docker-compose.ci.yml)
- [`docker/docker-compose.yml`](../../docker/docker-compose.yml)
- [CI Checks](ci-checks.md)
- [CI Troubleshooting](ci-troubleshooting.md)
