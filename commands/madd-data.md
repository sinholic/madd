---
description: "Ship data pipeline/migration changes: Sequelize migrations, seeds, ETL jobs. Enforces idempotency, rollback, dry-run, data integrity validation before any destructive change."
argument-hint: "<change description> [--type migration|seed|pipeline|etl|backfill]"
version: "1.0.0"
changelog: |
  1.0.0 — Initial runbook: migration safety gates, idempotency checks, rollback-first writing, dry-run, post-run validation
---

# Runbook: Ship data migration / pipeline change

You are executing `/madd-data`. Change: **$ARGUMENTS**

Goal: write data change safely. Down migration BEFORE up migration. Idempotency required. Dry-run before production run. Data integrity validated after run.

**Critical rule:** Never write an UP migration without its DOWN migration. Never run a migration without a rollback plan.

---

## Step 0 — Pre-flight

`Bash`:
```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
git status --short
```

`Read`: `AGENTS.md` — extract `LANGUAGE`, `FRAMEWORK`, `DATABASE`, `MIGRATION_CMD` (if present).

Detect migration tool:
```bash
# Sequelize
ls migrations/ 2>/dev/null | head -5
cat package.json 2>/dev/null | grep -E "sequelize|typeorm|prisma|knex|flyway|liquibase" | head -5

# Pipeline
ls src/pipeline/ src/jobs/ src/workers/ 2>/dev/null | head -5
```

Store `MIGRATION_TOOL` (sequelize / typeorm / prisma / knex / raw-sql / pipeline / seed / unknown).

Parse `$ARGUMENTS` for `--type <type>`. If provided, store as `DATA_TYPE`.
If not, infer from tool: migration → `migration`, seed file → `seed`, pipeline job → `pipeline`.

---

## Step 1 — Spec

Write spec adapted for data work:

```
**Change:** <one sentence describing what data changes>
**Type:** <migration | seed | pipeline | etl | backfill>
**DB target:** <database name / schema / collection>
**Tables / collections affected:** <list>
**Estimated rows affected:** <N rows or "all rows in <table>">

**Up migration behavior:**
  - <what SQL/operation does>
  - <resulting schema or data state>

**Down migration behavior (required):**
  - <exact reverse of up>
  - <any data that cannot be reversed — must flag explicitly>

**Idempotency guarantee:**
  - <yes — explain how (ON CONFLICT, existence check, etc.)>
  - <no — explain why and document manual guard required>

**Irreversible operations (must list explicitly):**
  - DROP COLUMN: yes/no
  - Data transformation (overwrite without backup): yes/no
  - DELETE or TRUNCATE: yes/no

**Pre-migration backup required:** yes / no / already in place
```

`AskUserQuestion`:
- question: "Spec correct and risks acknowledged?"
- header: "Spec gate"
- options:
  - "Approved — proceed"
  - "Revise spec"
  - "Abort"

---

## Step 2 — Schema analysis

Read current schema to understand impact:

**Sequelize / SQL:**
```bash
# List existing migrations
ls migrations/ | sort | tail -10

# Check current models for affected tables
grep -rn "tableName\|@Table\|@Entity" src/ --include="*.ts" | grep -i "<table-name>" | head -10
```

**MongoDB:**
```bash
grep -rn "Schema\|model(" src/ --include="*.ts" | grep -i "<collection>" | head -10
```

Read the most recent related migration file to understand current state. Understand:
- Current column types and constraints
- Existing indexes
- Foreign key relationships
- Any existing triggers or views depending on affected table

If finding something unexpected (column exists that spec says to add) → stop and ask user before proceeding.

---

## Step 3 — Write migration (DOWN first, then UP)

### 3a. Write DOWN migration first

**Why down first:** Forces thinking about reversibility before committing to the change.

For Sequelize:
```bash
# Generate migration file
npx sequelize-cli migration:generate --name <migration-name>
```

`Edit` the generated file. **Fill `down()` first:**

```javascript
async down(queryInterface, Sequelize) {
  // Exact reversal of up()
  // If drop column in up: add column back here with original type
  // If add column in up: drop column here
  // If create table in up: drop table here
  // If data transform in up: reverse transform (or flag as IRREVERSIBLE)
}
```

If operation is irreversible (data deleted, column type changed destructively):
```javascript
async down(queryInterface, Sequelize) {
  // IRREVERSIBLE: original data lost in up()
  // Manual recovery from backup required
  // Backup table: <backup_table_name_with_timestamp>
  throw new Error('IRREVERSIBLE: restore from backup <backup_table_name>');
}
```

### 3b. Write UP migration

Fill `up()` after `down()` is complete:

```javascript
async up(queryInterface, Sequelize) {
  // Idempotency guard (choose one):
  
  // Option A — Check existence first (for column adds):
  const tableDesc = await queryInterface.describeTable('<table>');
  if (!tableDesc['<column>']) {
    await queryInterface.addColumn('<table>', '<column>', { ... });
  }
  
  // Option B — CREATE TABLE IF NOT EXISTS
  await queryInterface.createTable('<table>', { ... }, { force: false });
  
  // Option C — ON CONFLICT DO NOTHING for data inserts
  await queryInterface.bulkInsert('<table>', [...], {
    ignoreDuplicates: true
  });
  
  // Option D — plain operation (document why idempotency guaranteed externally)
}
```

For **raw SQL files**: write `up.sql` and `down.sql` as separate files.

For **Prisma**: use schema migration file + verify `prisma migrate dev --name <name>` generates correct SQL.

### 3c. For seeds

Seeds must be idempotent:
```javascript
async up(queryInterface) {
  return queryInterface.bulkInsert('<table>', [
    { id: 1, name: 'Example', ... }
  ], {
    ignoreDuplicates: true  // or updateOnDuplicate for upsert behavior
  });
}

async down(queryInterface) {
  return queryInterface.bulkDelete('<table>', {
    id: [1, ...]  // exact IDs inserted in up
  });
}
```

**Never use hardcoded auto-increment IDs** in seeds. Use UUIDs or natural keys.

### 3d. For pipeline / ETL jobs

Check:
- Job has `--dry-run` or `--preview` mode
- Job has `--limit N` for testing on subset
- Job logs progress (rows processed, errors encountered)
- Job is resumable (checkpoint or last-processed-id tracking)
- Job has error threshold (stop if >X% rows fail)

---

## Step 4 — Idempotency validation

Review written migration for idempotency:

```bash
# If Sequelize: check the migration file
cat migrations/<timestamp>-<name>.js
```

Verify one of these patterns present in `up()`:
- `IF NOT EXISTS` / `IF EXISTS`
- Existence check before operation
- `ON CONFLICT DO NOTHING` / `ignoreDuplicates: true`
- `UPSERT` pattern
- Wrapped in transaction with explicit rollback on duplicate

If none found → `AskUserQuestion`:
- "Migration has no idempotency guard. Safe to run twice?"
- Options:
  - "Yes — migration is naturally idempotent (explain how)"
  - "No — add guard before proceeding"
  - "Partial — add note in migration comment"

---

## Step 5 — Dry-run / transaction test

### 5a. Dry-run check

Check if tool supports dry-run:

**Sequelize:** No native dry-run. Use transaction rollback pattern:
```bash
# Test migration inside a transaction that gets rolled back
node -e "
const { Sequelize } = require('sequelize');
const { up } = require('./migrations/<file>');
const seq = new Sequelize(process.env.DATABASE_URL);
seq.transaction(async t => {
  await up(seq.getQueryInterface(), Sequelize);
  console.log('Migration ran OK — rolling back');
  await t.rollback();
}).catch(e => { console.error('Migration error:', e.message); process.exit(1); });
"
```

**Prisma:** `prisma migrate dev --create-only` to generate SQL without running.

**Raw SQL:** Wrap in `BEGIN; ... ROLLBACK;` on staging DB.

**Pipeline jobs:** Run with `--dry-run` or `--limit 10` flag if available.

### 5b. Estimated rows check

Before running on production:
```sql
-- Count affected rows
SELECT COUNT(*) FROM <table> WHERE <migration-condition>;
```

If count > 100k rows: flag as high-impact migration. Ask user:
- `AskUserQuestion`:
  - "Migration touches >100k rows. Run strategy?"
  - Options:
    - "Run all at once (acceptable downtime)"
    - "Batch update (add --batch-size flag to migration)"
    - "Schedule for off-peak hours"
    - "Abort — needs more planning"

---

## Step 6 — Rollback plan confirmation

Before proceeding to run, confirm rollback is ready:

`AskUserQuestion`:
- question: "Rollback plan confirmed?"
- header: "Rollback gate"
- options:
  - "Yes — down() migration written and tested"
  - "Yes — backup snapshot taken before run"
  - "Yes — irreversible, backup table created in up()"
  - "No — need to prepare backup first"

If "No" → stop. Do not proceed without rollback.

---

## Step 7 — Run migration

### 7a. Staging first (required for schema changes)

```bash
# Sequelize (staging)
DATABASE_URL=<staging-url> npx sequelize-cli db:migrate

# Prisma (staging)
DATABASE_URL=<staging-url> npx prisma migrate deploy

# Verify status
DATABASE_URL=<staging-url> npx sequelize-cli db:migrate:status
```

`AskUserQuestion`:
- "Staging migration succeeded?"
- Options:
  - "Yes — proceed to production"
  - "No — errors found" → loop back to fix

### 7b. Production run

**Warning block (always shown):**

> **Before production migration:**
> 1. Backup confirmed (database snapshot or backup table).
> 2. Staging migration succeeded.
> 3. Down migration tested on staging.
> 4. Team notified if > 30s estimated downtime.

`AskUserQuestion`:
- question: "Run migration on production database?"
- header: "Production gate"
- options:
  - "Yes — run now"
  - "No — staging only for now"
  - "Abort"

If "Yes":
```bash
# Sequelize
npx sequelize-cli db:migrate

# Prisma
npx prisma migrate deploy
```

Capture full output. If any error → immediately run rollback:
```bash
npx sequelize-cli db:migrate:undo
```

---

## Step 8 — Post-run validation

### 8a. Schema integrity check

```bash
# Verify table structure matches expected
# Sequelize:
npx sequelize-cli db:migrate:status

# Manual check:
# psql / mysql: \d <table-name>
# MongoDB: db.<collection>.getIndexes()
```

### 8b. Data integrity check

Run validation queries based on spec:
```sql
-- Row count delta (should match estimated)
SELECT COUNT(*) FROM <table>;

-- Constraint satisfaction
SELECT COUNT(*) FROM <table> WHERE <affected-column> IS NULL;  -- Should be 0 if NOT NULL added

-- FK integrity
SELECT COUNT(*) FROM <child-table> ct
LEFT JOIN <parent-table> pt ON ct.parent_id = pt.id
WHERE pt.id IS NULL;  -- Should be 0
```

### 8c. App smoke test

```bash
<TEST_CMD>
```

All tests must pass. If any fail → investigate before declaring success.

### 8d. Pipeline job validation (if applicable)

Run job with `--limit 10` to verify output on real data:
```bash
node src/pipeline/<job> --limit 10 --verbose
```

Review output for expected transformations.

---

## Step 9 — Commit

```bash
git add migrations/ seeds/ src/pipeline/ WORKLOG.md
git commit -m "data: <change one-liner>

Type: <migration|seed|pipeline|etl|backfill>
Tables: <affected tables>
Rows affected: <estimate>
Rollback: <down() migration / backup table name>"
```

---

## Commit prefix discipline

| Type | Prefix |
|------|--------|
| Migration (schema) | `data(migration):` |
| Seed | `data(seed):` |
| Pipeline job | `data(pipeline):` |
| Backfill | `data(backfill):` |
| ETL | `data(etl):` |

---

## Failure modes

| Symptom | Recovery |
|---------|----------|
| Migration fails midway | Run `db:migrate:undo`; investigate error; fix; retry |
| Staging DB not available | Run in transaction-rollback dry-run locally |
| Down migration fails | DO NOT proceed to production. Fix down() first. |
| Row count much higher than estimated | Abort; re-estimate; consider batching |
| Tests fail after migration | Rollback immediately; investigate schema mismatch in app code |
| Duplicate key error in seed | Seed not idempotent; add `ignoreDuplicates: true` |
| Pipeline job OOM | Reduce batch size; add stream processing |

---

## Caveats

- DOWN migration is mandatory. Never merge a migration without it (except explicitly flagged IRREVERSIBLE with backup).
- Idempotency is non-negotiable for seeds and backfills — they may be re-run by CI/CD.
- Large table migrations (>1M rows) should use batched updates, not single ALTER TABLE.
- Never run `db:migrate` on production without staging run first.
- For destructive schema changes (DROP COLUMN): always create backup table in same migration: `CREATE TABLE <table>_bak_<timestamp> AS SELECT <dropped_cols> FROM <table>`.
- Safe backfill pattern for large tables: use `_migration_backfill_ids` helper table as checkpoint (see reference in memory: `reference_safe_backfill_migration_pattern.md`).
