#!/usr/bin/env bash
# Verify SBOM CPE coverage for the artifact, per §8/§9.
# k8s-core is pure-Go so most components present as Go-module PURLs rather than
# CPEs; this script accepts a PURL OR a CPE for each component. Components
# that have neither must be listed in policy/cpe-waivers.yaml or the script
# exits non-zero (the policy gate then refuses the release).
set -euo pipefail

sbom="${1:?sbom path}"
waivers="$(dirname "$0")/../policy/cpe-waivers.yaml"

missing=$(jq -r '
  .components // []
  | map(select(
      (.cpe == null or .cpe == "")
      and (.purl == null or .purl == "")
    ))
  | .[].name
' "$sbom" | sort -u)

if [ -z "$missing" ]; then
  exit 0
fi

# Compare against waivers.
if [ -f "$waivers" ]; then
  allowed=$(yq -r '.waived[]' "$waivers" 2>/dev/null || true)
  unwaived=$(comm -23 <(echo "$missing") <(echo "$allowed" | sort -u))
else
  unwaived="$missing"
fi

if [ -n "$unwaived" ]; then
  echo "verify-cpe-coverage: components without CPE/PURL and no waiver:" >&2
  echo "$unwaived" >&2
  exit 1
fi
