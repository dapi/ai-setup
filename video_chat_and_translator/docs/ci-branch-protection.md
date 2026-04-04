# Branch Protection Setup

Configure required status checks on `main` so that no PR can be merged unless all CI jobs pass.

## Required status check names

These names must match the `name:` fields of jobs in `.github/workflows/ci.yml` exactly:

| Job key | Display name (status check name) |
| --- | --- |
| `app` | `App checks (Docker)` |
| `lint` | `Lint` |
| `smoke-bootstrap` (ubuntu) | `Smoke (ubuntu-latest)` |
| `smoke-bootstrap` (macos) | `Smoke (macos-latest)` |

## Setup instructions

1. Go to the repository on GitHub.
2. Navigate to **Settings → Branches**.
3. Click **Add branch protection rule** (or edit the existing rule for `main`).
4. Set **Branch name pattern** to `main`.
5. Enable **Require a pull request before merging**.
6. Enable **Require status checks to pass before merging**.
7. In the search box, add each of the four check names listed above:
   - `App checks (Docker)`
   - `Lint`
   - `Smoke (ubuntu-latest)`
   - `Smoke (macos-latest)`
8. Enable **Require branches to be up to date before merging** (recommended).
9. Click **Save changes**.

## Verification

After setup, open a test PR and confirm that all four checks appear as required in the
merge box. The **Merge** button should be disabled until all four pass.
