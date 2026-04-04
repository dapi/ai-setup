# Docker Setup Guide

## Architecture

- **web**: Rails 8.1.3 + Vite dev server (Ruby 3.4.9, Node.js 22.x)
- **db**: PostgreSQL 17 (Alpine)
- **Network**: `video_chat_network` (dedicated bridge)

## Ports

| Service | Container Port | Host Port |
| --- | --- | --- |
| Rails | 3100 | ${PORT:-3100} |
| Vite | 3036 | 3036 |
| PostgreSQL | 5432 | random |

Note: Host port for Rails is controlled by `$PORT` env variable (set by `port-selector` via `.envrc`).

## Commands

```bash
# Build
docker compose -f docker/docker-compose.yml build

# Start
docker compose -f docker/docker-compose.yml up -d

# Stop
docker compose -f docker/docker-compose.yml down

# Logs
docker compose -f docker/docker-compose.yml logs -f web

# Rails console
docker compose -f docker/docker-compose.yml exec web bin/rails console

# Database
docker compose -f docker/docker-compose.yml run --rm web bin/rails db:create
docker compose -f docker/docker-compose.yml run --rm web bin/rails db:migrate

# Install gems
docker compose -f docker/docker-compose.yml run --rm web bundle install

# Install npm packages
docker compose -f docker/docker-compose.yml run --rm web yarn install
```

## Volumes

- `bundle_cache` — Ruby gems (persisted between rebuilds)
- `node_modules` — npm packages (persisted, container-native)
- `postgres_data` — database files

## Troubleshooting

- **PID file error**: Remove `tmp/pids/server.pid` before restarting
- **Port mismatch**: Check `$PORT` env variable on host (set by `port-selector`)
