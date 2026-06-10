---
description: "Security review: threats, mitigations, secrets, dependency CVEs, pen test plan, compliance gap. Produces SECURITY.md with risk matrix + audit roadmap. Real tool calls."
argument-hint: "[--scope <diff|all|files>] [--fix] [--no-pentest] [--no-compliance]"
version: "1.1.0"
changelog: |
  1.0.0 — Initial runbook: threat model, secret scan, dep audit, auth/authz check
  1.1.0 — Added Penetration Testing plan generation (Step 8) and Compliance Framework gap analysis (Step 9). Extended SECURITY.md template with both sections. Frameworks supported: OWASP MASVS L2 (mobile), OWASP ASVS L1/L2 (web/API), ISO/IEC 27001:2022 Annex A, ISO/IEC 27034, GDPR, UU PDP No. 27/2022 (Indonesia), BSSN/SPBE (Indonesia gov), PCI-DSS, SOC 2, HIPAA. PCI-DSS / HIPAA / GDPR explicitly checked for applicability before applying. New flags --no-pentest / --no-compliance to skip those steps. Restructured numbering: pen test = Step 8, compliance = Step 9, write = Step 10, optional fix = Step 11.
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

## Step 7 — Classify findings

For each finding, classify:

- **CRITICAL** — exploitable now (secret in history, missing auth on data endpoint, known CVE in critical dep, SQL injection)
- **HIGH** — exploitable with effort (weak auth, missing input validation, sensitive cookie without secure flag)
- **MEDIUM** — defense-in-depth gap (missing CSP, permissive CORS, outdated non-critical dep)
- **LOW** — best-practice deviation (no rate limit on non-sensitive endpoint, missing security headers)

Hold the classified findings in memory — they go into SECURITY.md at Step 10.

---

## Step 8 — Penetration testing plan

Skip if `--no-pentest` in $ARGUMENTS.

Goal: produce a defensible, scope-bound pen test plan that a human (or external CREST/BSSN-certified firm) can execute. NOT executing the pen test — only planning.

### 8a. Determine surface

From AGENTS.md `FRAMEWORK` + `DEPLOYMENT`, classify the target:

- **Mobile app (Android / iOS / React Native)** → OWASP MASVS L2 + MSTG methodology
- **Web app / SPA** → OWASP ASVS L2 + WSTG
- **REST / GraphQL API** → OWASP API Security Top 10 + ASVS L2
- **CLI / desktop binary** → reversing + supply-chain + privilege escalation
- **Library / SDK** → API surface fuzzing + threat-model walkthrough
- **Mixed** → multiple methodologies, document overlap

### 8b. Identify threat actor profiles

`AskUserQuestion` (or infer from `AGENTS.md` deployment / domain context):

- **Curious user** — owns valid creds, exploring
- **Disgruntled employee** — insider, knows internals
- **Cybercrime** — off-the-shelf tools, financial motive
- **Hacktivist** — public APK / source, embarrassment motive
- **Foreign state actor** — APT capability, MITM, supply-chain (escalate for gov / regulated targets)

Per profile, note: capability, goal, most relevant tests.

### 8c. Define rules of engagement (RoE)

Always require:

| Constraint | Default | When to override |
|------------|---------|------------------|
| Test window | Off-peak only | If 24x7 ops, schedule maintenance window |
| Notification lead time | 24h prior to each session | Increase to 1wk for prod |
| Test data | Synthetic accounts only (prefix `pentest_*`) | Never use real user data |
| Destructive ops | Forbidden (deletion, schema migration, mass lockout, sustained DoS) | Only on dedicated stage env w/ written approval |
| Exploit verification | Read-only PoC (1 record + screenshot) | Never bulk exfil |
| Reporting | 24h for HIGH+, immediate call for CRITICAL | — |
| Cleanup | All test artifacts removed within 48h | — |
| Signed RoE document | Required pre-kickoff | Anything not explicitly allowed = forbidden |

### 8d. Map test methodology to phases

Generate phase-by-phase plan per surface (mobile example shown — adapt patterns to web / API / etc.):

**Phase 1 — Reconnaissance (no prod traffic)**
- Static analysis: `apktool`, `jadx`, `hermes-dec`, `strings`, `MobSF`, `semgrep`, `gitleaks`
- Dependency CVE scan: results from Step 3
- Hardcoded string inventory

**Phase 2 — Dynamic instrumentation (rooted / emulator)**
- Frida hooks: dump API calls, intercept storage APIs, log crypto
- MITM proxy: `mitmproxy` / Burp; SSL pinning bypass via `objection`

**Phase 3 — API fuzzing (synthetic accounts on prod or stage)**
- Endpoint enumeration from captured traffic
- IDOR / BOLA testing (Object-A creds + Object-B identifier)
- Auth bypass / SQLi via `sqlmap`
- Rate-limit testing via `ab` or `wrk`

**Phase 4 — Channel-specific tests** (MDM channel for mobile, OAuth callback for web, message-queue injection for backend, etc.)

**Phase 5 — Local storage forensics** (Android: `run-as` + sqlite; iOS: device backup parse)

**Phase 6 — Custom URL / deep link abuse**

### 8e. Define acceptance criteria

Map to selected standard's L2 / L3 requirements (e.g. MASVS L2 24-control checklist, ASVS L2 controls). Each control gets:

- ✅ covered (by which code/test)
- 🟡 partial (gap noted)
- ❌ missing (action item, links to finding in Step 7 list)

### 8f. List tooling

Per surface, list tools the human/firm will need:

- **Static (mobile):** apktool, jadx, hermes-dec, MobSF, semgrep, gitleaks
- **Static (web):** semgrep, retire.js, sourcemap-explorer, OWASP Dependency-Check
- **Dynamic (mobile):** Frida, objection, Burp Suite Pro, mitmproxy, Drozer
- **Dynamic (web):** Burp Suite Pro, OWASP ZAP, Selenium for auth flows
- **API:** Postman, ffuf, sqlmap, nuclei, OWASP ZAP, GraphQL Voyager
- **Forensics:** `adb backup`, `dd` on rooted device, Magisk modules, MobileXR

### 8g. Specify deliverables

Pen test must produce (these go in the plan as required outputs):

1. Executive summary (1 page, severity rollup, business risk)
2. Technical report (per-finding: title, severity, CVSS v3.1 score, evidence screenshots, repro steps, fix recommendation)
3. Compliance mapping (each finding mapped to applicable standards — Step 9 will inform)
4. Remediation appendix (priority order, effort estimate, retest plan)
5. Raw artifacts (Burp project, Frida logs, scan reports) for archive

Hold the assembled plan in memory for Step 10 (SECURITY.md write).

---

## Step 9 — Compliance framework gap analysis

Skip if `--no-compliance` in $ARGUMENTS.

### 9a. Detect applicability

Score each framework based on AGENTS.md + signals from prior steps:

| Framework | Applicability signals | Action if applicable |
|-----------|----------------------|----------------------|
| **OWASP ASVS L1/L2** | Any web app / API | Always include — baseline for non-mobile |
| **OWASP MASVS L1/L2** | Mobile app (RN, native, hybrid) | Always include for mobile |
| **OWASP API Top 10** | Any API surface | Always include if API endpoints found in Step 4 |
| **ISO/IEC 27001:2022 Annex A** | Enterprise / regulated / commercial product | Include if AGENTS.md notes enterprise deployment OR if `--all` |
| **ISO/IEC 27034 (App Security)** | Same as 27001 | Companion to 27001 |
| **PCI-DSS v4** | Cardholder data processed | DETECT: grep code for "card", "cvv", "cardholder", "PAN", "stripe", "paypal-credit", payment processor SDK imports. **If NONE found → mark N/A** + state so explicitly. Do NOT apply gratuitously. |
| **HIPAA** | US healthcare PHI | DETECT: grep for "PHI", "patient", "diagnosis", "medical record". US deployment hint from domain/timezone. **If NONE → N/A**. |
| **GDPR** | EU resident data | DETECT: EU deployment signals (eu-* AWS region, .eu domain), explicit EU user base. **If NONE → conditional**. |
| **UU PDP No. 27/2022 (Indonesia)** | Indonesian deployment / Indonesian user data / Indonesian gov | DETECT: `.id` domain, `Asia/Jakarta` timezone in code, Bahasa Indonesia UI strings, Indonesian institution name in package/manifest. |
| **BSSN / SPBE (Indonesia gov)** | Indonesian government agency | DETECT: gov agency name in package/manifest (e.g. `kejaksaan`, `kominfo`, `kemenkeu`), `.go.id` domain. |
| **SOC 2 Type II** | SaaS w/ enterprise customers | Optional; include if `--all` or AGENTS.md notes enterprise SaaS context. |
| **NIST 800-53 / 800-171** | US federal deployment | Optional. |

`AskUserQuestion` when ambiguous: confirm which apply.

### 9b. Map control gaps per applicable framework

For each applicable framework, generate a gap table:

```
| <Framework> Control | Requirement (1 line) | Status | Gap action / link to finding |
```

Status: ✅ covered / 🟡 partial / ❌ missing / 🚫 N/A (with reason).

Reuse findings from Steps 2-6 as evidence. E.g., HTTPS gap (Step 6) → maps to MASVS NETWORK-1, ISO A.8.20, UU PDP Art. 16(1)(g), PCI-DSS Req 4.1.

Where the framework has many controls, focus on mobile-relevant / app-layer subset (don't drag in physical security, BCP/DR, etc., unless app touches them).

### 9c. Generate compliance roadmap

Time-bound rollup:

- **Q1 (now):** controls needed for legal compliance (UU PDP, GDPR, HIPAA, PCI-DSS if applicable — these have penalties)
- **Q2:** controls needed for OWASP MASVS / ASVS L2 acceptance
- **Q3-Q4:** ISO 27001 Stage 1 prep, external pen test, certification audit

### 9d. PCI-DSS / HIPAA / GDPR N/A caveats

If any of these were marked N/A in Step 9a, explicitly write `## Out of scope` blurb in SECURITY.md explaining the trigger condition that would make them applicable. Don't silently omit.

Hold the compliance section in memory for Step 10.

---

## Step 10 — Write SECURITY.md

`Write` to `<repo-root>/SECURITY.md`:

```markdown
# Security Review — <ISO date>

**Scope:** <scope>
**Findings:** <total> (Critical: N, High: N, Medium: N, Low: N)
**Status:** <auditor-name | "AI agent (madd-secure v1.1.0)">

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

## Risk matrix (post-remediation tracking)

| Finding | Severity | Status | Resolution / Blocker |
|---------|----------|--------|----------------------|
| 1. <title> | CRITICAL | ⏳ Open | <fix plan or RESOLVED via commit hash> |

Status legend: ⏳ Open / 🔧 In progress / ✅ Resolved / ⏸️ Deferred / 🚫 Blocked

---

## Action plan

1. Rotate any leaked secrets (Critical)
2. Patch critical CVEs (`<pm> update <pkg>`)
3. Add auth checks to flagged endpoints
4. Add input validation to flagged boundaries
5. Defense-in-depth: CSP, CORS hardening, cookie flags

---

## Penetration Testing Plan

*(omit this whole section if Step 8 skipped via `--no-pentest`)*

This is a **plan**, not a completed test. Execution requires authorization from the system owner and ideally an external CREST-certified / BSSN-recognized firm.

### Scope

**In scope:** <list, e.g. mobile client v0.3.0+, API endpoints, MDM channel, deep links, local storage>

**Out of scope (separate engagements):**
- Backend source code review (covered by <repo> SECURITY.md)
- Infrastructure (DB, VPC, load balancers)
- Vendor security (treat as black-box)
- Physical / social engineering
- DDoS / availability testing

### Rules of engagement

<table from Step 8c>

### Threat actor profiles

<table from Step 8b>

### Test methodology

<phases from Step 8d>

### Acceptance criteria

<mapping from Step 8e: MASVS L2 / ASVS L2 control table, score X/Y covered>

### Tools

<list from Step 8f>

### Deliverables

<list from Step 8g>

---

## Compliance Framework Gap Analysis

*(omit this whole section if Step 9 skipped via `--no-compliance`)*

### Applicability summary

| Framework | Applicability | Why |
|-----------|--------------|-----|
| <Framework 1> | ✅ REQUIRED | <reason> |
| <Framework 2> | 🟡 RECOMMENDED | <reason> |
| PCI-DSS | ❌ NOT APPLICABLE | App does NOT process / store / transmit cardholder data. <Re-evaluate if payment flows added.> |
| HIPAA | ❌ NOT APPLICABLE | No US healthcare PHI processed. |
| GDPR | 🟡 CONDITIONAL | <Indonesia-only scope → not currently applicable. Re-evaluate before EU deployment.> |

### Per-framework gap tables

<one section per applicable framework, with control table from Step 9b>

### Compliance roadmap

<from Step 9c>

---

## Out of scope (this audit)

- iOS hardening (no iOS distribution yet) <example>
- Backend API security (separate repo)
- MDM (vendor) policy review
- Penetration testing execution (planned above, not performed)
- Compliance certification audit (gap analysis only)

Frameworks marked N/A above:
- PCI-DSS: <re-evaluate trigger>
- HIPAA: <re-evaluate trigger>
- GDPR: <re-evaluate trigger>

---

## Compliance notes (summary)

- Framework: <FRAMEWORK from AGENTS.md>
- Deployment: <DEPLOYMENT from AGENTS.md>
- Standards considered: <list>
- Penalties exposure: <e.g., UU PDP Art. 65 up to 2% annual revenue / IDR 5B>
```

---

## Step 11 — Optional fix

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
| All clean (Steps 2-6) | Still run Steps 8-9 — pen test plan + compliance gap are valuable artifacts even with zero findings |
| Pen test scope ambiguous | `AskUserQuestion` for in/out of scope; default to "mobile + API only, infra out" |
| Compliance framework over-applied | Re-check Step 9a detection signals; mark N/A with explicit re-evaluate trigger |
| User passes `--no-pentest --no-compliance` | Skip Steps 8-9 entirely; Step 10 omits those sections |

---

## Caveats

- **Never** commit a SECURITY.md to a public repo if it contains Critical findings before they're fixed. Use `.gitignore` for the file during remediation.
- Auto-fix CRITICAL only with explicit per-finding confirmation.
- Secret in git history requires rotation + history scrub + force-push — not a quick fix.
- This skill is a baseline. Full pentest execution and certification audit (ISO 27001 Stage 1+2, SOC 2 attestation, PCI-DSS QSA assessment) require human security engineer / certified auditor for high-risk apps.
- **Pen test plan is NOT pen test execution.** Step 8 generates a defensible plan a human / external firm can execute under signed RoE. Never run intrusive tests from this skill against production.
- **Compliance gap analysis is NOT certification.** Step 9 identifies which controls are covered / missing. Achieving compliance requires evidence collection, policy documentation, leadership sign-off, and (for ISO/SOC 2) external audit. The SECURITY.md output is input to that process, not the output of it.
- **Be conservative with PCI-DSS / HIPAA / GDPR applicability.** Do NOT apply these gratuitously. Each has its own trigger condition (cardholder data / US PHI / EU data subject). Marking them N/A correctly is more valuable than dragging in irrelevant controls.
- **Regional frameworks:** UU PDP (Indonesia) and BSSN/SPBE apply to Indonesian deployment / agencies. Detect via `.id` domain, Asia/Jakarta timezone, Bahasa Indonesia strings, agency name in package. Extend Step 9a applicability table for other regions (LGPD Brazil, POPIA South Africa, PIPL China, etc.) as needed for the project.
