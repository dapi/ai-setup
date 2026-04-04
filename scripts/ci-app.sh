#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE=(docker compose -f "${ROOT_DIR}/docker/docker-compose.ci.yml")

cleanup() {
	"${COMPOSE[@]}" down -v
}
trap cleanup EXIT

mkdir -p "${ROOT_DIR}/tmp/ci-artifacts"
"${COMPOSE[@]}" build web 2>&1 | tee "${ROOT_DIR}/tmp/ci-artifacts/docker-build-log.txt"
"${COMPOSE[@]}" run --rm web bin/setup --skip-server
"${COMPOSE[@]}" run --rm web bin/ci
