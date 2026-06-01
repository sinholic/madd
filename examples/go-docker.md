# AGENTS.md — example: Go service + Docker

Reference scaffold for a Go HTTP service deploying via Docker (Kubernetes, ECS, Fly, or self-hosted).

---

## Stack

| Layer | Technology |
|-------|-----------|
| Language | Go 1.23 |
| HTTP | net/http + chi router (or Echo/Fiber) |
| Database | Postgres (sqlx or sqlc) |
| Test runner | go test (built-in) + testcontainers for integration |
| Linter | golangci-lint |
| Container | Multi-stage Dockerfile (distroless final) |
| Deployment | Docker → registry → K8s / ECS / Fly / Nomad |

## Key commands

```bash
go run ./cmd/server                   # Dev server
go build -o bin/server ./cmd/server   # Build binary
go test ./...                          # Run all tests
go test -race ./...                    # With race detector
go test -cover ./...                   # With coverage
go vet ./...                           # Static analysis
golangci-lint run                      # Comprehensive lint
gofmt -w .                             # Format
go mod tidy                            # Clean deps
docker build -t myservice:latest .     # Container build
docker run -p 8080:8080 myservice      # Local container run
```

## Directory structure

```
cmd/
  server/             main package — wires HTTP server
    main.go
internal/             Private packages — not importable externally
  api/                HTTP handlers + middleware
  service/            Business logic
  repository/         Data access (sqlx, sqlc)
  domain/             Domain types
  config/             Env-driven config
pkg/                  Public packages (only if importable)
migrations/           Goose or golang-migrate SQL files
Dockerfile            Multi-stage build
docker-compose.yml    Local Postgres + service
Makefile              Common dev shortcuts
go.mod / go.sum
```

## Delivery workflow

`/madd-ship <description>`. 8-phase SDD+TDD.

## Conventions

| Convention | Policy |
|------------|--------|
| Feature flags | No, direct change — services are versioned; redeploy on rollback |
| Comments | WHY only; godoc on exported (`Capitalized`) names |
| Error handling | Wrap with context (`fmt.Errorf("doing X: %w", err)`); return at boundaries |
| Commit prefixes | `schema:` / `test(red):` / `feat:` / `refactor:` / `fix:` |
| Concurrency | Channels for orchestration; mutex for state; race detector in CI |
| Dependencies | Stdlib first; only add module when stdlib insufficient |

## Notes specific to this stack

- **Error wrapping:** Always `fmt.Errorf("operation failed: %w", err)` to preserve chain. Use `errors.Is` / `errors.As` at boundaries.
- **Context propagation:** Every request handler accepts and propagates `ctx context.Context`. Cancel cascades on client disconnect.
- **Graceful shutdown:** `http.Server.Shutdown(ctx)` on SIGTERM. Drain in-flight requests with timeout.
- **Migrations:** Goose or golang-migrate. Commit migration files as `schema:`. Never edit applied migrations.
- **Distroless images:** Use `gcr.io/distroless/static-debian12` for final stage. No shell → smaller attack surface.
- **Healthcheck endpoint:** `/healthz` (liveness), `/readyz` (readiness checks DB connection). Required for K8s/ECS.
- **Structured logging:** `log/slog` (Go 1.21+) with JSON handler in prod. Include `trace_id`, `request_id`.
- **Test pyramid:** Unit tests (table-driven) > integration (testcontainers) > E2E (separate suite, run on PR). Race detector mandatory in CI.
- **Config from env:** Use `envconfig` or `viper`. `.env.example` documents all vars. Fail fast on startup if required vars missing.
