#!/usr/bin/env bash
# Poll each descriptor's advisory_sources and open one GitHub Issue per
# CVE×component that's new since last run. Cursor state is keyed by
# (component, cve) and persisted to patch-manifests/state/cve-cursor.json,
# committed back to main.
#
# Robustness: any single source fetch failing must NOT abort the whole run,
# otherwise one flaky feed silences the entire monitor. Errors are logged
# inline and the loop continues.
set -uo pipefail   # no -e — see comment above

state_dir="patch-manifests/state"
state="${state_dir}/cve-cursor.json"
mkdir -p "$state_dir"
[ -f "$state" ] || echo '{}' > "$state"

# Returns 0 if (component,cve) is already known.
known() {
  jq -e --arg c "$1" --arg v "$2" '.[$c] // [] | index($v) | type=="number"' "$state" >/dev/null
}
remember() {
  jq --arg c "$1" --arg v "$2" '.[$c] = (((.[$c] // []) + [$v]) | unique)' "$state" > "$state.tmp"
  mv "$state.tmp" "$state"
}

open_issue() {
  local component="$1" tier="$2" cve="$3" source_url="$4" summary="$5"
  if known "$component" "$cve"; then
    return 0
  fi
  if gh issue create \
    --title "[${component}] ${cve} — advisory triage" \
    --label "advisory,${tier},bundle:k8s-1.32,applicability:needs-review,cve:${cve}" \
    --body "$(cat <<EOF
Component: **${component}**  (tier ${tier})
CVE: **${cve}**
Source: ${source_url}

${summary}

Auto-opened by .github/workflows/advisory-monitor.yml. Triage:
1. Confirm applicability per binary (see LTS-BRANCHING.md on the source fork).
2. If not-applicable, write a VEX entry in the release evidence and close.
3. If applicable, open a backport PR on the source fork and link it here.

KEV / actively-exploited: follow docs/runbook-kev-hotfix.md.
EOF
)" >/dev/null 2>&1; then
    remember "$component" "$cve"
    echo "opened: $component / $cve"
  else
    echo "WARN: failed to open issue for $component / $cve (likely missing label or rate limit)" >&2
  fi
}

extract_cves() {
  grep -oE 'CVE-[0-9]{4}-[0-9]{4,7}' | sort -u
}

poll_kev() {
  local url="$1"
  curl -fsSL --max-time 30 "$url" 2>/dev/null \
    | jq -r '.vulnerabilities[]? | select((.product // "") | test("[Kk]ubernetes|kubelet|kube-")) | .cveID' 2>/dev/null \
    | sort -u
}

poll_generic() {
  local url="$1"
  curl -fsSL --max-time 30 "$url" 2>/dev/null | extract_cves
}

for desc in components/*.yaml; do
  comp=$(yq -r '.name' "$desc")
  tier=$(yq -r '.tier' "$desc")
  src_count=$(yq -r '.advisory_sources | length' "$desc")
  echo "== ${comp} (${tier}): ${src_count} sources =="
  for i in $(seq 0 $((src_count - 1))); do
    kind=$(yq -r ".advisory_sources[$i].kind" "$desc")
    url=$(yq -r  ".advisory_sources[$i].url"  "$desc")
    case "$kind" in
      kev) cves=$(poll_kev "$url" || true) ;;
      *)   cves=$(poll_generic "$url" || true) ;;
    esac
    n=$(printf '%s\n' "$cves" | grep -c CVE- || true)
    echo "  ${kind} <- ${url}  (${n} CVE ids)"
    for cve in $cves; do
      open_issue "$comp" "$tier" "$cve" "$url" "Detected via ${kind} feed."
    done
  done
done

# Persist cursor back to main, if changed.
if [ -n "$(git status --porcelain "$state" 2>/dev/null)" ]; then
  git config user.email "advisory-monitor@users.noreply.github.com"
  git config user.name  "advisory-monitor[bot]"
  git add "$state"
  git commit -m "advisory-monitor: cursor update" && git push || echo "WARN: cursor push failed (non-fatal)"
fi
