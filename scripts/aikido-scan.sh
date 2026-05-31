#!/usr/bin/env bash
# Aikido primary scanner (§8). This is a stub until Aikido procurement closes
# (see docs/infra-setup.md#aikido). Until then the workflow falls through to
# Grype + Trivy supplemental — the gate consumes the merged findings file.
set -euo pipefail

sbom= ; out=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sbom) sbom="$2"; shift 2;;
    --out)  out="$2"; shift 2;;
    *) echo "aikido-scan: unknown arg $1" >&2; exit 2;;
  esac
done
[[ -z "$sbom" || -z "$out" ]] && { echo "aikido-scan: --sbom and --out required" >&2; exit 2; }

mkdir -p "$(dirname "$out")"

if [ -z "${AIKIDO_TOKEN:-}" ]; then
  # Emit an empty-findings document so merge-findings.sh has something to read.
  echo '{"source":"aikido","status":"skipped","reason":"AIKIDO_TOKEN unset","findings":[]}' > "$out"
  exit 0
fi

# TODO(infra-setup.md#aikido): replace with the real Aikido SBOM-upload API
# call once the endpoint is known.
echo '{"source":"aikido","status":"stub","findings":[]}' > "$out"
