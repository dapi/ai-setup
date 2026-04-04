# CI Troubleshooting

See also: [CI Checks](ci-checks.md) | [CI Parity](ci-parity.md)

## Registry unavailable / image pull failure

**Symptom:** build step fails with `pull access denied`, `connection timed out`, or `no such host`.

**Steps:**

1. Check [Docker Hub status](https://www.dockerstatus.com/) and any corporate mirror/registry.
2. If transient: **re-run** the workflow in GitHub Actions (Actions → workflow run → Re-run jobs).
3. If persistent: verify that the GitHub Actions runner has outbound access to the registry.
4. Download the `ci-failure-logs` artifact and inspect `docker-build-log.txt` for the exact error.

## Build fails (non-network)

**Symptom:** `App checks (Docker)` job fails at the "Build Docker image" step.

**Steps:**

1. Download the `ci-failure-logs` artifact from the workflow run summary.
2. Open `docker-build-log.txt` — it contains the full `docker compose build` stdout/stderr.
3. Reproduce locally: `./scripts/ci-app.sh` — the build log is saved to `tmp/ci-artifacts/docker-build-log.txt`.

## Checks fail (RuboCop / Brakeman / Bundler Audit)

**Symptom:** `App checks (Docker)` job fails at the "Run CI checks" step.

**Steps:**

1. Download `ci-failure-logs` artifact and inspect `docker-compose-runtime-logs.txt`.
2. Reproduce locally: `./scripts/ci-app.sh` — output is printed to stdout.
3. Fix the reported issues and push again.

## Database setup fails

**Symptom:** job fails at the "Setup database" step.

**Steps:**

1. Inspect `docker-compose-runtime-logs.txt` in the `ci-failure-logs` artifact.
2. Common cause: migration error or schema mismatch. Check recent migrations.
3. Reproduce locally: `./scripts/ci-app.sh`.

## Artifacts not uploaded

**Symptom:** job failed but no `ci-failure-logs` artifact appears.

**Reason:** the `upload-artifact` step only runs `if: failure()`. If the job was cancelled
(not failed), artifacts are not uploaded.

**Fix:** re-run the job and let it fail naturally rather than cancelling it.

## Downloading artifacts

GitHub Actions → repository → Actions → select the failed workflow run →
Summary → Artifacts → `ci-failure-logs` → Download.
