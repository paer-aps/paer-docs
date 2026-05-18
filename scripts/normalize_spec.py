#!/usr/bin/env python3
"""Normalize a fetched OpenAPI spec for docs.paer.dk publication.

Two transforms (Item 16 Phase 2):

1. **Drop internal + admin paths.** FastAPI already hides them via
   `include_in_schema=False`; this is defense-in-depth in case a future
   route is added without the flag.

2. **Rewrite customer paths to the `/v1/public/*` canonical prefix.**
   Per-service rules describe which top-level path segments under `/v1/`
   are customer-facing; the rewriter prepends `/v1/public/` to each.
   Other paths (`/`, `/health`, anything outside `/v1/`) pass through.

Usage:
    normalize_spec.py <input.json> <output.json> <service_name>

`<service_name>` is one of: quotes, user, beneficiary, cvr — selects the
rewrite ruleset below.
"""

from __future__ import annotations

import json
import sys
from typing import Iterable


# Per-service top-level path segments that are customer-facing. Anything
# under `/v1/<seg>/...` for `seg` in this set gets rewritten to
# `/v1/public/<seg>/...`. Anything NOT in this set is passed through
# unchanged (e.g. `/v1/internal/*` would be skipped — but those are also
# dropped first by `_should_drop`).
CUSTOMER_TOP_LEVEL: dict[str, set[str]] = {
    "quotes": {"quotes", "fx"},
    "user": {"auth", "api-keys", "billing", "users", "companies"},
    "beneficiary": {"beneficiaries"},
    "cvr": {"cvr"},
}


def _should_drop(path: str) -> bool:
    """Drop any operator- or inter-service path that slipped through."""
    if path.startswith("/v1/internal/"):
        return True
    if path.startswith("/v1/admin/"):
        return True
    return False


def _rewrite_to_public(path: str, customer_tops: Iterable[str]) -> str:
    """Rewrite `/v1/<top>/...` → `/v1/public/<top>/...` when `<top>` is in
    the customer-facing allowlist. Pass-through otherwise."""
    if not path.startswith("/v1/"):
        return path
    if path.startswith("/v1/public/"):
        return path  # already canonical
    # /v1/<top>[/...]
    rest = path[len("/v1/") :]
    top = rest.split("/", 1)[0]
    if top in customer_tops:
        return "/v1/public/" + rest
    return path


def normalize(spec: dict, service: str) -> dict:
    customer_tops = CUSTOMER_TOP_LEVEL.get(service, set())
    new_paths: dict[str, dict] = {}
    for path, ops in spec.get("paths", {}).items():
        if _should_drop(path):
            continue
        new_paths[_rewrite_to_public(path, customer_tops)] = ops
    spec["paths"] = new_paths
    return spec


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: normalize_spec.py <in.json> <out.json> <service>", file=sys.stderr)
        return 2
    in_path, out_path, service = sys.argv[1], sys.argv[2], sys.argv[3]
    if service not in CUSTOMER_TOP_LEVEL:
        print(f"unknown service: {service!r}", file=sys.stderr)
        return 2
    with open(in_path) as f:
        spec = json.load(f)
    spec = normalize(spec, service)
    with open(out_path, "w") as f:
        json.dump(spec, f, indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
