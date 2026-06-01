# AGENTS.md — example: Django + Fly.io

Reference scaffold for a Django app deploying to Fly.io.

---

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | Django 5.x |
| Language | Python 3.12 |
| Package manager | uv (or pip + Pipfile / pyproject.toml) |
| Test runner | pytest + pytest-django |
| Database | Postgres (Fly Managed Postgres or Supabase) |
| Deployment | Fly.io (`fly.toml`, Dockerfile) |
| WSGI/ASGI | Gunicorn + Uvicorn workers |

## Key commands

```bash
uv sync                              # Install deps
uv run python manage.py runserver    # Dev server (localhost:8000)
uv run python manage.py migrate      # Apply migrations
uv run python manage.py makemigrations  # Create migrations
uv run python manage.py shell        # REPL
uv run pytest                         # Run tests
uv run pytest --cov                   # With coverage
uv run ruff check .                   # Lint
uv run mypy .                         # Type check
fly deploy                            # Deploy to Fly.io
fly logs                              # Stream prod logs
fly ssh console                       # Shell into prod VM
```

## Directory structure

```
project/                  Django project (settings, urls, wsgi)
  settings/
    base.py
    dev.py
    prod.py
apps/
  <app_name>/             One Django app per bounded context
    models.py
    views.py
    serializers.py        (if DRF)
    urls.py
    tests/
    migrations/
manage.py
pyproject.toml            uv + tool config
fly.toml                  Fly.io deployment
Dockerfile
.env.example              Documented env vars (committed)
```

## Delivery workflow

`/madd-ship <description>`. 8-phase SDD+TDD.

## Conventions

| Convention | Policy |
|------------|--------|
| Feature flags | Yes, opt-in only — django-waffle for risky changes |
| Comments | WHY only; docstrings on public model/serializer/view classes |
| Error handling | Boundaries only — DRF serializers, form validation, middleware |
| Commit prefixes | `schema:` / `test(red):` / `feat:` / `refactor:` / `fix:` (migrations: `schema:`) |
| Type hints | Required on all public functions; `mypy --strict` for new modules |

## Notes specific to this stack

- **Migrations are schema commits:** Every model change → `makemigrations` → commit as `schema: <change>`. Never edit applied migrations.
- **Fly.io zero-downtime deploy:** Default `release_command` runs `migrate` before traffic shift. Add to `fly.toml` `[deploy]` section.
- **Secrets:** `fly secrets set KEY=value` for prod. Local `.env` (gitignored). `.env.example` documents required vars.
- **Postgres connection pooling:** Use `pgbouncer` for serverless-style burst; configure `CONN_MAX_AGE` for persistent.
- **Background jobs:** Django-Q2 or Celery + Redis. Run as separate Fly app or process group in `fly.toml`.
- **Static + media files:** Serve via Whitenoise (static) + S3/R2 (user uploads). Never serve media from app server.
- **DEBUG=False in prod:** Verify `settings/prod.py` does not enable DEBUG. Security audit each release.
- **ALLOWED_HOSTS:** Set via env var, include `.fly.dev` for default Fly hostname.
