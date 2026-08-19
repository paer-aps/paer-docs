#!/usr/bin/env bash
# Pull the four OpenAPI specs from the live deployments into specs/.
#
# Run locally before committing if you want to refresh the docs site
# manually. CI runs this on a daily cron and on workflow_dispatch.
#
# Why bake specs vs fetch live from the browser:
# - No CORS coupling between the docs site and the three API services.
# - Page loads instantly (no client-side fetch waterfall).
# - Reproducible: a doc URL renders the same spec every time until refreshed.
#
# Post-processing (Item 16 Phase 2):
# Each fetched spec is run through `scripts/normalize_spec.py` which:
#   - Strips any `/v1/internal/*` or `/v1/admin/*` paths that slipped through
#     (defense-in-depth; FastAPI already hides them via include_in_schema=False).
#   - Rewrites customer-facing `/v1/<top>/...` paths to `/v1/public/<top>/...`
#     so the published docs advertise the canonical Item-16 path. Each service
#     has an ASGI middleware that accepts both prefixes during the cutover.

# Keeping the previous spec on a failed fetch is deliberate — a transient blip
# must not blank the published docs. Exiting 0 as well was the mistake: from
# 2026-07-18 the services stopped serving /openapi.json at all (ENABLE_DOCS
# =false on the rebuilt ECS task definitions, exactly the case this repo's
# CLAUDE.md predicted), every fetch 404'd, and the job reported success while
# publishing specs frozen since May. Degrade gracefully, but never quietly:
# stale content is served, and the run goes red so someone is told.
set -euo pipefail

cd "$(dirname "$0")/.."

declare -A URLS=(
  [quotes]=https://api.paer.dk/openapi.json
  [user]=https://user-api.paer.dk/openapi.json
  [beneficiary]=https://beneficiary-api.paer.dk/openapi.json
  [cvr]=https://cvr-api.paer.dk/openapi.json
)

FAILED=()

for svc in "${!URLS[@]}"; do
  url="${URLS[$svc]}"
  out="specs/${svc}.json"
  echo "fetching ${svc} ← ${url}"
  if ! curl -fsS --max-time 15 "$url" -o "${out}.raw"; then
    echo "  ✗ fetch failed; keeping existing ${out}"
    rm -f "${out}.raw"
    FAILED+=("$svc (fetch)")
    continue
  fi
  if ! python3 scripts/normalize_spec.py "${out}.raw" "${out}.tmp" "$svc"; then
    echo "  ✗ normalize failed; keeping existing ${out}"
    rm -f "${out}.raw" "${out}.tmp"
    FAILED+=("$svc (normalize)")
    continue
  fi
  rm -f "${out}.raw"
  mv "${out}.tmp" "$out"
  echo "  ✓ $(wc -c < "$out") bytes"
done

echo
echo "diff vs HEAD:"
git diff --stat specs/ 2>/dev/null || true

if (( ${#FAILED[@]} > 0 )); then
  echo
  echo "==================== SPEC REFRESH INCOMPLETE ===================="
  echo "Could not refresh: ${FAILED[*]}"
  echo
  echo "The previous spec files are untouched, so docs.paer.dk keeps serving"
  echo "its last good content — but that content is now STALE for the services"
  echo "listed above, and the site gives no sign of it."
  echo
  echo "Most likely cause: the service no longer publishes /openapi.json."
  echo "ENABLE_DOCS is false on the production task definitions, which makes"
  echo "the public spec endpoint 404 by design. If that is intended to stay,"
  echo "this script needs a different source — generate each spec in the"
  echo "service's own CI (app.openapi() at build time) and publish it as an"
  echo "artifact, rather than scraping a live public endpoint."
  echo "================================================================"
  exit 1
fi
