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

set -euo pipefail

cd "$(dirname "$0")/.."

declare -A URLS=(
  [quotes]=https://api.paer.dk/openapi.json
  [user]=https://user-api.paer.dk/openapi.json
  [beneficiary]=https://beneficiary-api.paer.dk/openapi.json
  [cvr]=https://cvr-api.paer.dk/openapi.json
)

for svc in "${!URLS[@]}"; do
  url="${URLS[$svc]}"
  out="specs/${svc}.json"
  echo "fetching ${svc} ← ${url}"
  if ! curl -fsS --max-time 15 "$url" -o "${out}.raw"; then
    echo "  ✗ fetch failed; keeping existing ${out}"
    rm -f "${out}.raw"
    continue
  fi
  if ! python3 scripts/normalize_spec.py "${out}.raw" "${out}.tmp" "$svc"; then
    echo "  ✗ normalize failed; keeping existing ${out}"
    rm -f "${out}.raw" "${out}.tmp"
    continue
  fi
  rm -f "${out}.raw"
  mv "${out}.tmp" "$out"
  echo "  ✓ $(wc -c < "$out") bytes"
done

echo
echo "diff vs HEAD:"
git diff --stat specs/ 2>/dev/null || true
