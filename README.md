# paer-docs

Unified API reference for the paer.dk platform. Hosted on GitHub Pages at
https://docs.paer.dk.

A single Scalar-rendered page renders three OpenAPI specs side-by-side:

- **Quotes API** (`api.paer.dk`) — FX quote + cross-border execution
- **User API** (`user-api.paer.dk`) — identity, KYB, API key issuance
- **Beneficiary API** (`beneficiary-api.paer.dk`) — counterparties + sanctions/PEP/adverse-media screening

## How it works

Specs are **baked at build time** rather than fetched at runtime. The
`scripts/refresh_specs.sh` script pulls each service's `/openapi.json` into
`specs/*.json`, and `index.html` references those local files. This avoids
CORS coupling between the docs site and the three backends, and gives stable
load times.

A scheduled GitHub Actions workflow (`refresh.yml`) re-pulls daily at 06:00 UTC
and commits any drift; that triggers the `deploy.yml` workflow which publishes
the site.

```
docs.paer.dk
   │
   ▼
GitHub Pages (paer-aps.github.io/paer-docs)
   │
   ▼ static files
specs/{quotes,user,beneficiary}.json + index.html
   │
   ├─ refreshed daily by .github/workflows/refresh.yml (cron + dispatch)
   └─ rendered by Scalar (https://cdn.jsdelivr.net/npm/@scalar/api-reference)
```

## Local preview

```bash
./scripts/refresh_specs.sh        # optional — only if you want fresh specs
python3 -m http.server 8080       # browse http://localhost:8080
```

## Manual refresh after a backend deploy

```bash
gh workflow run refresh.yml -R paer-aps/paer-docs
```

## Adding a new service

1. Append the service URL to the dict at the top of `scripts/refresh_specs.sh`.
2. Append the service to the `sources` array in `index.html`.
3. Run `./scripts/refresh_specs.sh` and commit.

## DNS

`docs.paer.dk` CNAME → `paer-aps.github.io` (added at Simply.com).

GitHub Pages serves Let's Encrypt certs automatically; "Enforce HTTPS" is
turned on in the repo settings under Pages.
