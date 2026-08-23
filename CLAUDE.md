# CLAUDE.md

Static site for `docs.paer.dk` — unified API reference across the three
backend services. Hosted on GitHub Pages.

## What this repo is

Just static files. No build step, no Node, no Python runtime needed for
the deploy. The "build" is "copy these files to a CDN".

```
index.html                         # Scalar embed; references specs/ via relative URLs
specs/quotes.json                  # baked OpenAPI from api.paer.dk/openapi.json
specs/user.json                    # baked OpenAPI from user-api.paer.dk/openapi.json
specs/beneficiary.json             # baked OpenAPI from beneficiary-api.paer.dk/openapi.json
scripts/refresh_specs.sh           # pulls live specs into specs/ — used by CI + locally
.github/workflows/deploy.yml       # publishes to GH Pages on push to main
.github/workflows/refresh.yml      # daily cron + dispatch — refreshes specs/ + auto-commits
CNAME                              # docs.paer.dk
```

## Why baked specs (and not live `<script src="…/openapi.json">`)

The Scalar embed CAN fetch OpenAPI URLs at runtime. We don't, on purpose:

1. **No CORS coupling** — three FastAPI services don't need
   `https://docs.paer.dk` in their `cors_origins` allowlist.
2. **Fast first paint** — no waterfall of three JSON fetches at page load.
3. **Reproducibility** — a permalink to a specific commit renders the
   exact spec snapshot that was current at build time.

The trade-off is freshness: specs are at most 24h stale. Mitigated by:
- Daily cron in `refresh.yml`.
- `gh workflow run refresh.yml` after any backend deploy.
- A future improvement is to have each backend service's `deploy.yml`
  fire `workflow_dispatch` here automatically.

## Build status

Last updated **2026-04-28**.

| Status | Item |
|---|---|
| ✅ | index.html with Scalar multi-source embed |
| ✅ | specs/{quotes,user,beneficiary}.json baked from live |
| ✅ | scripts/refresh_specs.sh — keeps the previous spec on a failed fetch, but **exits non-zero** so the run goes red (silent fallback froze the site for a month — meta #108) |
| ⛔ | **The published specs are stale and cannot currently be refreshed.** `ENABLE_DOCS=false` on the production ECS task definitions, so every service's `/openapi.json` 404s — the case this file's "When to update" section predicted. Needs a source decision: expose the spec endpoint again, or generate each spec in the service's own CI (`app.openapi()` at build time) and publish it as an artifact. Tracked on meta #108. |
| ✅ | .github/workflows/deploy.yml — GH Pages on push to main |
| ✅ | .github/workflows/refresh.yml — daily cron + workflow_dispatch with auto-commit |
| ✅ | CNAME = docs.paer.dk |
| ◻ | Live at https://docs.paer.dk (pending DNS at Simply.com + GH Pages enable) |

## Common commands

```bash
# Refresh specs locally
./scripts/refresh_specs.sh

# Preview locally
python3 -m http.server 8080
# → open http://localhost:8080

# Force a CI refresh + redeploy
gh workflow run refresh.yml -R paer-aps/paer-docs
gh workflow run deploy.yml  -R paer-aps/paer-docs
```

## Related repos and references

- `paer-aps/paer-quotes-api` — Quotes API (`api.paer.dk`)
- `paer-aps/paer-user-api` — User API (`user-api.paer.dk`)
- `paer-aps/paer-beneficiary-api` — Beneficiary API (`beneficiary-api.paer.dk`)
- `paer-aps/paer-app` — customer-facing frontend (`app.paer.dk`)

## When to update

- **A backend ships new endpoints** → run `gh workflow run refresh.yml` (or wait for the daily cron).
- **A new backend service is added** → edit `scripts/refresh_specs.sh` (URLs map) AND `index.html` (sources array).
- **Branding/theme change** → edit the `data-configuration` JSON on the Scalar embed in `index.html`.
- **`ENABLE_DOCS=false` flipped on services pre-launch** → switch the refresh script to authenticated fetches (the public `/openapi.json` will go dark; need an internal CI route or a vendored copy).
