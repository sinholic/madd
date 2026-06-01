# AGENTS.md — example: Astro 5 + Cloudflare Workers

Reference scaffold produced by `/madd-init existing` for an Astro SSR project on Cloudflare Workers.

---

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | Astro 5 (SSR via Cloudflare adapter) |
| Content | MDX + Content Collections |
| Language | TypeScript (strict) |
| Package manager | pnpm 10.x |
| Test runner | Vitest |
| Deployment | Cloudflare Workers via Wrangler (`wrangler.json`) |
| Runtime | Node 22+ (local), Workers runtime (prod) |

## Key commands

```bash
pnpm dev          # Dev server (localhost:4321)
pnpm build        # astro build
pnpm preview      # Build + Wrangler local preview (closest to prod)
pnpm check        # astro build && tsc && wrangler deploy --dry-run
pnpm deploy       # Deploy to Cloudflare Workers
pnpm cf-typegen   # Regenerate Cloudflare env types
pnpm test         # vitest run
pnpm test:watch   # vitest watch
```

## Directory structure

```
src/
  components/     Astro components (.astro)
  content/        MDX content collections (blog, portfolio, etc.)
  layouts/        Page layout wrappers
  lib/            Pure TypeScript utilities
  pages/          File-based routing
    api/          Cloudflare Worker endpoints
  styles/         global.css — design tokens
  types/          Shared interfaces
public/           Static assets
wrangler.json     Cloudflare Workers config
```

## Delivery workflow

`/madd-ship <description>`. 8-phase SDD+TDD.

## Conventions

| Convention | Policy |
|------------|--------|
| Feature flags | No, direct change — instant rollback via Cloudflare redeploy |
| Comments | WHY only |
| Error handling | Boundaries only — Astro endpoints + form handlers |
| Commit prefixes | `schema:` / `test(red):` / `feat:` / `refactor:` / `fix:` |

## Notes specific to this stack

- **Cloudflare bindings:** Run `pnpm cf-typegen` after editing `wrangler.json` bindings (KV, R2, D1, Durable Objects, secrets) to regenerate `worker-configuration.d.ts`.
- **Local dev vs prod:** `pnpm dev` runs Astro dev (Node). `pnpm preview` runs the actual built Worker via Wrangler — use for any Workers-runtime-specific behavior.
- **Secrets:** `.dev.vars` for local; `wrangler secret put` for prod. Never commit secrets.
- **Edge runtime quirks:** No Node APIs in route handlers. Web Crypto, fetch, Headers, Response only.
- **Content collections:** Schemas in `src/content.config.ts`. Run `pnpm dev` once after changes to regenerate types.
