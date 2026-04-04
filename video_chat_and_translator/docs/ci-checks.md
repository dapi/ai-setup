# CI Checks

Canonical entry point: `bin/ci` (defined in `video_chat_and_translator/bin/ci` + `config/ci.rb`).

## Required checks

| # | Check | Command |
| --- | --- | --- |
| 1 | RuboCop | `bin/rubocop` |
| 2 | Bundler Audit | `bin/bundler-audit` |
| 3 | Brakeman | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` |

**RSpec:** not connected — skipped (as of 2026-04-04).
`spec/` does not exist and `rspec-rails` is not in Gemfile. When RSpec is added, update this document and `bin/ci`.

## Running checks locally (Docker)

Use `scripts/ci-app.sh` to reproduce CI in Docker with full parity:

```bash
./scripts/ci-app.sh
```

This script:

- Builds the Docker image using the same CI compose file as GitHub Actions
- Runs `bin/setup --skip-server` to prepare the database
- Runs `bin/ci` for all checks
- Saves the build log to `tmp/ci-artifacts/docker-build-log.txt`
- Tears down containers and volumes on exit (via `trap`)

See [`docker/docker-compose.ci.yml`](../../docker/docker-compose.ci.yml) for CI environment configuration.

## Docker build log policy

On every CI run, the full `docker compose build` stdout/stderr is captured via `tee` into
`docker-build-log.txt`. If the build step fails, this file is always available in the
`ci-failure-logs` artifact — even if container logs are empty or unavailable.

## Artifacts and diagnostics

When the `App checks (Docker)` job fails, GitHub Actions uploads a `ci-failure-logs` artifact.

**Artifact contents:**

| File | When present | Description |
| --- | --- | --- |
| `docker-build-log.txt` | Always (created by `tee` during build step) | Full stdout/stderr of `docker compose build` |
| `docker-compose-runtime-logs.txt` | On failure after build succeeds | Output of `docker compose logs` |
| `test.log` | On failure if file exists in container | Rails test log at `log/test.log` |

**JUnit XML:** not connected — no Tests tab in GitHub Actions UI.
Integrate after RSpec is added: configure `--format RspecJunitFormatter` and upload the XML file as an artifact.

**Downloading artifacts:**
GitHub Actions → workflow run → Summary → Artifacts section → `ci-failure-logs`.

See also: [CI Troubleshooting](ci-troubleshooting.md)
