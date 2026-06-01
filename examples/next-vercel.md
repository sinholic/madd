# AGENTS.md — example: Next.js + Vercel

Reference scaffold for a Next.js App Router project deploying to Vercel.

---

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 15 (App Router, RSC) |
| Language | TypeScript (strict) |
| Package manager | pnpm 9.x |
| Test runner | Vitest + Playwright (E2E) |
| Styling | Tailwind CSS |
| Deployment | Vercel |
| Runtime | Node 20+ (Vercel runtime) |

## Key commands

```bash
pnpm dev          # Next dev server (localhost:3000)
pnpm build        # next build
pnpm start        # Production server (after build)
pnpm lint         # next lint
pnpm typecheck    # tsc --noEmit
pnpm test         # vitest run
pnpm test:e2e     # playwright test
pnpm deploy       # vercel --prod (or via git push to main)
```

## Directory structure

```
src/
  app/                  App Router root
    (marketing)/        Route group (no URL segment)
    api/                Route handlers
    layout.tsx
    page.tsx
  components/
    ui/                 Shared primitives (shadcn pattern)
    features/           Feature-scoped components
  lib/                  Utilities, server actions, db
  hooks/                Client hooks
  types/                Shared types
public/                 Static assets
vercel.json             Vercel config (optional)
```

## Delivery workflow

`/madd-ship <description>`. 8-phase SDD+TDD.

## Conventions

| Convention | Policy |
|------------|--------|
| Feature flags | Yes, opt-in only — flag risky changes (auth, payments); use Vercel Edge Config |
| Comments | WHY only |
| Error handling | Boundaries only — route handlers, server actions, form parsers |
| Commit prefixes | `schema:` / `test(red):` / `feat:` / `refactor:` / `fix:` |
| Server vs Client | Default to Server Components; `'use client'` only when interactivity required |

## Notes specific to this stack

- **App Router:** Prefer Server Components. Mark `'use client'` only for stateful UI, event handlers, browser APIs.
- **Server actions:** Validate input with Zod at the action boundary. Never trust client payloads.
- **Vercel Preview Deployments:** Every PR gets a preview URL — use for Phase 7 UAT instead of local-only.
- **Env vars:** `.env.local` for dev; Vercel Dashboard for staging/prod. `NEXT_PUBLIC_*` prefix for client-exposed.
- **Image optimization:** Use `next/image`. Configure remote patterns in `next.config.ts`.
- **Rate limits on Hobby tier:** `image-optimization` and serverless invocations capped. Audit per-feature for cost.
- **Edge vs Node runtime:** Default Node. Switch to `export const runtime = 'edge'` only when measurably faster + Web-API-compatible.
