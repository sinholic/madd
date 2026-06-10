---
description: "Validate and ship DevOps/infra changes: Dockerfile, docker-compose, CI/CD pipelines, worker config, deploy scripts. Produces DEVOPS-REVIEW.md."
argument-hint: "[--type docker|compose|ci|worker|deploy|k8s] [--files <paths>] [--fix]"
version: "1.0.0"
changelog: |
  1.0.0 — Initial runbook: infra type detection, per-type validation, security checks, DEVOPS-REVIEW.md
---

# Runbook: DevOps / infra validation

You are executing `/madd-devops`. Args: **$ARGUMENTS**

Goal: validate infra config changes for correctness, security, and reliability. Produce DEVOPS-REVIEW.md.

---

## Step 0 — Pre-flight

`Bash`:
```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
git status --short
```

`Read`: `AGENTS.md` — extract `BUILD_CMD`, `DEPLOY_CMD`, `LANGUAGE`, `FRAMEWORK`.

---

## Step 1 — Determine scope and type

Parse `$ARGUMENTS`:
- `--type <type>` → explicit type
- `--files <paths>` → explicit files
- `--fix` → apply fixes after review

If no `--type` → auto-detect from changed files:
```bash
git diff HEAD --name-only
```

Map files to infra types:
- `Dockerfile*` → `docker`
- `docker-compose*.yml` → `compose`
- `.gitlab-ci.yml`, `.github/workflows/*.yml`, `Jenkinsfile` → `ci`
- `worker/`, `*queue*`, `*job*`, `*bull*` config files → `worker`
- `Makefile`, `scripts/deploy*`, `*.sh` (deploy context) → `deploy`
- `k8s/`, `helm/`, `*.yaml` with `kind:` → `k8s`

If multiple types detected → set `INFRA_TYPES` (array). Review each.

If still unclear → `AskUserQuestion`:
- "What type of infra change is this?"
- Options: Docker / docker-compose / CI/CD pipeline / Worker config / Deploy script / Kubernetes

---

## Step 2 — Read config files

For each file in scope: `Read` full file.

If too large (>500 lines single file): read in sections — focus on secrets, env vars, resource config, and execution steps.

---

## Step 3 — Type-specific validation

### 3a. Dockerfile

Check:
- **Base image pinned?** `:latest` is forbidden. Must use `image:digest` or `image:x.y.z`.
- **Non-root user?** `USER` directive present. Running as root = FAIL.
- **HEALTHCHECK defined?** Required for production services.
- **Layer ordering for cache?** COPY dependencies + install BEFORE copying source.
- **Multi-stage build?** Required for compiled languages. Build artifacts only in final stage.
- **Secrets in build args?** `ARG SECRET=` or `ENV API_KEY=` = CRITICAL.
- **`COPY . .` without .dockerignore?** Warn if `.dockerignore` missing.
- **Unnecessary packages?** `apt-get install` without `--no-install-recommends` + `rm -rf /var/lib/apt/lists/*`

```bash
test -f .dockerignore && echo "HAS_DOCKERIGNORE" || echo "MISSING_DOCKERIGNORE"
```

### 3b. docker-compose

Check:
- **Version field** present (warn if using obsolete v2 syntax in compose v3+ projects)
- **Secrets via env_file** not hardcoded in `environment:` block
- **Named volumes** used for persistent data (not bind-mount for databases)
- **`restart: unless-stopped`** (or `always`) on production services
- **Resource limits** (`mem_limit`, `cpus`) present for resource-heavy services
- **No `privileged: true`** without explicit justification comment
- **Network isolation** — services not on default bridge unless intentional
- **Healthcheck conditions** in `depends_on:` (not just service name)

### 3c. CI/CD pipelines (GitLab CI / GitHub Actions)

**GitLab CI (`.gitlab-ci.yml`):**
- `GITLAB_TOKEN` / `CI_JOB_TOKEN` not echoed to logs
- `allow_failure: true` only on non-critical stages
- Cache keys include branch or lockfile hash (not static)
- `only:` / `rules:` prevents prod deploy on feature branches
- `environment:` declared for deploy jobs (enables GitLab environment tracking)
- Artifacts have `expire_in` set
- `image:` pinned (not `:latest`)

**GitHub Actions (`.github/workflows/*.yml`):**
- `permissions:` scoped to minimum needed (not `contents: write` when read is enough)
- Secrets accessed via `${{ secrets.NAME }}` not hardcoded
- `pull-request: write` not granted to untrusted input workflows
- `actions/checkout` uses pinned SHA, not floating tag
- Third-party actions pinned to commit SHA (not `@v2`)

### 3d. Worker / job config (Bull, BullMQ, Sidekiq, etc.)

Check:
- **Retry count defined** — no infinite retry without backoff
- **Backoff strategy** — exponential or fixed delay, not immediate re-queue
- **Job timeout** — long-running jobs have timeout set
- **Concurrency** — explicit concurrency limit (not unbounded)
- **Dead letter queue** — failed jobs move to DLQ, not silently dropped
- **Job deduplication** — idempotent job IDs for jobs that must not run twice
- **Queue priority** — critical jobs not starved by low-priority backlog

### 3e. Deploy scripts (Makefile, shell scripts)

Check:
- `set -euo pipefail` at top of bash scripts (fail fast)
- No hardcoded credentials or tokens
- Idempotency — safe to run twice
- Rollback function defined (or rollback method documented)
- `--dry-run` mode available for destructive operations
- Environment variables validated before use (`${VAR:?error message}`)
- No `rm -rf` on paths constructed from unvalidated variables

### 3f. Kubernetes manifests

Check:
- `resources.requests` and `resources.limits` both set
- `readinessProbe` + `livenessProbe` defined
- `securityContext.runAsNonRoot: true`
- `imagePullPolicy: Always` for production (not `IfNotPresent` with mutable tags)
- `secrets` sourced from `secretKeyRef` not `configMapKeyRef`
- RBAC: `ServiceAccount` has minimum permissions
- No `hostNetwork: true` or `hostPID: true` without justification

---

## Step 4 — Cross-cutting security checks

Across ALL infra types:

```bash
# Scan for potential secret patterns
grep -rn "password\|secret\|token\|key\|api_key\|auth" \
  $(git diff HEAD --name-only | tr '\n' ' ') 2>/dev/null \
  | grep -v "\.md\|#\|comment\|placeholder\|example\|test" \
  | grep -iE "=\s*['\"][^'\"]{8,}" \
  | head -20
```

Flag any hardcoded secrets as CRITICAL immediately.

Also check:
- `.env` files committed (should be in `.gitignore`)
- Private keys or certificates in repo

```bash
find . -maxdepth 4 -name "*.pem" -o -name "*.key" -o -name ".env" 2>/dev/null | grep -v ".gitignore"
```

---

## Step 5 — Write DEVOPS-REVIEW.md

`Write` to `<repo-root>/DEVOPS-REVIEW.md`:

```markdown
# DevOps Review — <ISO date>

**Scope:** <files reviewed>
**Infra types:** <types detected>
**Findings:** <total> (Critical: N, High: N, Medium: N, Low: N)

---

## CRITICAL

### 1. <title>
**File:** `<path>:<line>`
**Type:** <docker|ci|compose|worker|deploy|k8s>
**Issue:** <description>
**Risk:** <what goes wrong if unfixed>
**Fix:**
```<lang>
<suggestion>
```

---

## HIGH

...

---

## MEDIUM

...

---

## LOW

...

---

## Summary

- Deploy blocked by: <list CRITICAL + HIGH if any>
- Safe to deploy: <YES / NO — explain>
- Recommend: <prioritized fix order>
```

---

## Step 6 — Report + optional fix

Print summary.

If `--fix` in args OR `AskUserQuestion`:
- "Apply fixes now?"
- Options:
  - "Apply Critical + High"
  - "Apply all"
  - "Review only"
  - "Selective — per finding"

For each fix: `Read` → `Edit` → verify no syntax error (re-`Read` to confirm).

Commit prefix: `infra:` for infra fixes, `ci:` for pipeline fixes, `deploy:` for deploy script fixes.

---

## Failure modes

| Symptom | Recovery |
|---------|----------|
| YAML parse error in CI config | Fix syntax first; re-run |
| Secret detected — unclear if real | Flag CRITICAL; ask user to confirm if placeholder |
| Multiple infra types — review too broad | Split by `--type`; run separate reviews |
| Kubernetes not accessible | Static analysis only; skip live cluster checks |
| Worker config is code (not config) | Use `/madd-review` for logic; use this for config sections only |

---

## Caveats

- CRITICAL secret findings block ship — do not auto-fix (risk of overwrite). Ask user.
- Infra changes often have org-level conventions not in AGENTS.md — ask if uncertain.
- This runbook validates config, not application code inside containers. Use `/madd-review` for app logic.
- For deploy scripts touching production: always confirm before running `--fix`.
