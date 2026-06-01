---
description: "Security review: threats, mitigations, secrets, dependency CVEs. Produces SECURITY.md with risk matrix. Real tool calls."
argument-hint: "[--scope <diff|all|files>] [--fix]"
version: "1.0.0"
changelog: |
  1.0.0 — Initial runbook: threat model, secret scan, dep audit, auth/authz check
---

# Runbook: Security review

You are executing `/madd-secure`. Args: **$ARGUMENTS**

Goal: surface security risks across threats, secrets, dependencies, auth. Produce SECURITY.md with prioritized remediation.

---

## Step 0 — Pre-flight

`Bash`:
```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
git status --short
```

`Read`: `AGENTS.md` — extract `LANGUAGE`, `FRAMEWORK`, `DEPLOYMENT`, security controls if documented.

---

## Step 1 — Determine scope

Parse $ARGUMENTS:
- `--scope diff` → unstaged + staged changes
- `--scope all` → full repo (heavier)
- `--scope files` → ask user for paths
- (none) → `AskUserQuestion` — default to `diff`

---

## Step 2 — Secret scan

### 2a. In source files

`Bash`:
```bash
# Common secret patterns — extend per project
git grep -nE '(AKIA[0-9A-Z]{16}|ghp_[a-zA-Z0-9]{36}|sk-[a-zA-Z0-9]{20,}|xox[bp]-[0-9a-zA-Z-]+|-----BEGIN (RSA|EC|DSA|PRIVATE) KEY-----)' -- ':!*.lock' ':!*.lockb' ':!node_modules' ':!.git' 2>/dev/null || echo "no obvious secrets"
```

### 2b. In .env / config

`Bash`:
```bash
find . -maxdepth 3 -type f \( -name '.env*' -o -name '*.config.*' -o -name 'secrets.*' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null
```

For each: `Read` → flag any real-looking values (not placeholders like `<your-key>`).

### 2c. In git history (recent)

`Bash`:
```bash
git log -p --all -S 'AKIA' -S 'ghp_' -S 'sk-' --since='30 days ago' 2>/dev/null | head -50
```

If hits → CRITICAL finding: secret in history, even if removed from working tree.

---

## Step 3 — Dependency CVE check

Detect package manager + run audit:

`Bash`:
```bash
# Node
test -f package.json && {
  pm=$(jq -r '.packageManager // empty' package.json 2>/dev/null | sed 's/@.*//')
  case "$pm" in
    pnpm*) pnpm audit --json 2>/dev/null | jq '.advisories // .' | head -50 ;;
    yarn*) yarn npm audit --json 2>/dev/null | head -50 ;;
    *)     npm audit --json 2>/dev/null | jq '.vulnerabilities // .' | head -50 ;;
  esac
}

# Python
test -f Pipfile && pip-audit 2>/dev/null | head -30
test -f pyproject.toml && pip-audit 2>/dev/null | head -30
test -f requirements.txt && pip-audit -r requirements.txt 2>/dev/null | head -30

# Rust
test -f Cargo.toml && cargo audit 2>/dev/null | head -30

# Go
test -f go.mod && command -v govulncheck >/dev/null && govulncheck ./... 2>/dev/null | head -30
```

Capture vulnerabilities. Severity per advisory (critical / high / moderate / low).

---

## Step 4 — Auth / authz audit

For each route handler / API endpoint in scope, check:

### 4a. Identify endpoints

`Bash`:
```bash
# Framework-specific patterns — extend per AGENTS.md
case "<FRAMEWORK>" in
  astro|next)
    find . -path '*/pages/api/*' -o -path '*/app/api/*' -o -path '*/routes/*' 2>/dev/null | grep -v node_modules | head -30
    ;;
  express|fastify|hono)
    grep -rE '\.(get|post|put|delete|patch)\(' --include='*.ts' --include='*.js' . 2>/dev/null | grep -v node_modules | head -30
    ;;
  django)
    find . -name 'urls.py' -not -path '*/.venv/*' 2>/dev/null
    ;;
  rails)
    test -f config/routes.rb && cat config/routes.rb
    ;;
esac
```

### 4b. Check for auth on each

`Read` each endpoint file. For each handler, verify:
- Auth check present (session, token, cookie)
- Authorization check (user owns resource / has role)
- Rate limiting if sensitive (login, password reset)

Flag missing auth as HIGH or CRITICAL (depends on what endpoint exposes).

---

## Step 5 — Input validation audit

For each external input boundary (route handlers, form processors, message consumers):

- Is input validated against schema? (Zod, Joi, Pydantic, etc.)
- Are user-supplied strings sanitized before reaching:
  - SQL (parameterized? ORM-safe?)
  - Shell (any `exec`/`spawn` with user input?)
  - HTML output (escaped?)
  - File paths (resolved against allowed base?)
  - Eval / dynamic code (never?)

`Bash`:
```bash
# Hunt for dangerous patterns
git grep -nE '(eval\(|exec\(|child_process|shell=True|dangerouslySetInnerHTML|innerHTML\s*=)' \
  -- ':!node_modules' ':!*.lock' 2>/dev/null | head -30
```

---

## Step 6 — Transport / config audit

Check:

- **HTTPS only** in prod? (look for `http://` in non-dev configs)
- **CORS** — restrictive? (no `*` for credentialed endpoints)
- **CSP** — set? (look for `Content-Security-Policy` headers)
- **Cookies** — `Secure`, `HttpOnly`, `SameSite`?
- **Secrets storage** — env vars not hardcoded?

`Bash`:
```bash
grep -rnE '(Access-Control-Allow-Origin|Content-Security-Policy|sameSite|httpOnly|secure:\s*(true|false))' \
  --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.rb' \
  . 2>/dev/null | grep -v node_modules | head -30
```

---

## Step 7 — Classify + write SECURITY.md

For each finding, classify:

- **CRITICAL** — exploitable now (secret in history, missing auth on data endpoint, known CVE in critical dep, SQL injection)
- **HIGH** — exploitable with effort (weak auth, missing input validation, sensitive cookie without secure flag)
- **MEDIUM** — defense-in-depth gap (missing CSP, permissive CORS, outdated non-critical dep)
- **LOW** — best-practice deviation (no rate limit on non-sensitive endpoint, missing security headers)

`Write` to `<repo-root>/SECURITY.md`:

```markdown
# Security Review — <ISO date>

**Scope:** <scope>
**Findings:** <total> (Critical: N, High: N, Medium: N, Low: N)

---

## 🔴 CRITICAL

### 1. <title>
**File:** `<path>:<line>` (or "git history" for secret leaks)
**Issue:** <description>
**Impact:** <what an attacker can do>
**Fix:**
\`\`\`<lang>
<code or step>
\`\`\`
**Verification:**
<how to confirm fix>

---

## 🟠 HIGH
...

## 🟡 MEDIUM
...

## ⚪ LOW
...

---

## Dependency CVEs
| Package | Version | CVE | Severity | Fix version |
|---------|---------|-----|----------|-------------|
| ... | ... | ... | ... | ... |

---

## Action plan

1. Rotate any leaked secrets (Critical)
2. Patch critical CVEs (`<pm> update <pkg>`)
3. Add auth checks to flagged endpoints
4. Add input validation to flagged boundaries
5. Defense-in-depth: CSP, CORS hardening, cookie flags

---

## Compliance notes

- Framework: <FRAMEWORK>
- Deployment: <DEPLOYMENT>
- Standards considered: <e.g. OWASP Top 10, project-specific>
```

---

## Step 8 — Optional fix

If `--fix` OR `AskUserQuestion`:

For LOW + MEDIUM: auto-fix where safe (e.g., add `httpOnly: true`, update dep versions).

For HIGH + CRITICAL: **never auto-fix without explicit per-finding OK**. Security fixes have wide impact; require deliberate review.

For secret-in-history: **never auto-fix**. Process required:
1. Rotate the secret externally
2. Use `git filter-repo` or BFG to scrub history
3. Force-push (coordinate with team)

Tell user manually for these.

---

## Failure modes

| Symptom | Recovery |
|---------|----------|
| `npm audit` rate-limited | Use `--offline` or skip; retry later |
| `cargo audit` not installed | Suggest install; skip dep check |
| Framework not recognized | Fall back to grep-based heuristics |
| False positive secret | Add to `.gitignore` or document in SECURITY.md as accepted |
| All clean | Write SECURITY.md saying "no findings"; still valuable as audit record |

---

## Caveats

- **Never** commit a SECURITY.md to a public repo if it contains Critical findings before they're fixed. Use `.gitignore` for the file during remediation.
- Auto-fix CRITICAL only with explicit per-finding confirmation.
- Secret in git history requires rotation + history scrub + force-push — not a quick fix.
- This skill is a baseline. Full pentest / threat model requires human security engineer for high-risk apps.
