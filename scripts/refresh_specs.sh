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
  if ! curl -fsS --max-time 15 "$url" | python3 -m json.tool > "${out}.tmp"; then
    echo "  ✗ failed; keeping existing ${out}"
    rm -f "${out}.tmp"
    continue
  fi
  mv "${out}.tmp" "$out"
  echo "  ✓ $(wc -c < "$out") bytes"
done

echo
echo "diff vs HEAD:"
git diff --stat specs/ 2>/dev/null || true
