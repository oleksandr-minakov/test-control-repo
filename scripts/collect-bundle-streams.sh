#!/usr/bin/env bash
# Resolve the bundle manifest into a release-time JSON pinning each stream to
# its current candidate digest (images) or deb_version (debs).
set -euo pipefail

bundle= ; release_tag= ; out=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle)      bundle="$2"; shift 2;;
    --release-tag) release_tag="$2"; shift 2;;
    --out)         out="$2"; shift 2;;
    *) echo "collect-bundle-streams: unknown arg $1" >&2; exit 2;;
  esac
done

bundle_file="bundles/${bundle}.yaml"
[ -f "$bundle_file" ] || { echo "bundle not found: $bundle_file" >&2; exit 1; }

mapfile -t streams < <(yq -r '.streams[]' "$bundle_file")

jq_in=()
for s in "${streams[@]}"; do
  # stream_id => streams/k8s-1.32/<component>-1.32.yaml
  comp="${s%%-1.32-lts.k8s-1.32}"
  f="streams/k8s-1.32/${comp}-1.32.yaml"
  [ -f "$f" ] || { echo "stream metadata missing: $f" >&2; exit 1; }
  jq_in+=("$(yq -o=json '.' "$f")")
done

# Compose final manifest
printf '%s\n' "${jq_in[@]}" \
  | jq -s --arg bundle "$bundle" --arg tag "$release_tag" \
      '{bundle: $bundle, release_tag: $tag, streams: .}' \
  > "$out"
