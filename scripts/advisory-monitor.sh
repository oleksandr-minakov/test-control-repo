#!/usr/bin/env bash
# Poll each descriptor's advisory_sources and open one GitHub Issue per
# CVE×component that's new since last run. Cursor state is keyed by
# (component, cve) and persisted to patch-manifests/state/cve-cursor.json,
# committed back to main.
#
# Sources supported with real CVE extraction:
#   * github-advisory  — GitHub Security Advisories JSON (gh api or atom)
#   * vendor-page      — kubernetes.io official CVE feed (atom)
#   * mailing-list     — kubernetes-security-announce (atom)
#   * kev              — CISA KEV JSON
#   * osv              — OSV.dev API
#
# Caveats: each feed schema differs; we extract CVE IDs by regex
# (CVE-YYYY-NNNN) from titles + bodies. This is deliberately conservative —
# false positives are cheap (one extra triage Issue), missed CVEs are not.
set -euo pipefail

state_dir="patch-manifests/state"
state="${state_dir}/cve-cursor.json"
mkdir -p "$state_dir"
[ -f "$state" ] || echo '{}' > "$state"

# Returns 0 if (component,cve) is already known.
known() {
  jq -e --arg c "$1" --arg v "$2" '.[$c] // [] | index($v) | type=="number"' "$state" >/dev/null
}

# Marks (component,cve) as known.
remember() {
  jq --arg c "$1" --arg v "$2" '.[$c] = (((.[$c] // []) + [$v]) | unique)' "$state" > "$state.tmp"
  mv "$state.tmp" "$state"
}

# Open one issue per (component, CVE). Idempotent via the cursor.
open_issue() {
  local component="$1" tier="$2" cve="$3" source_url="$4" summary="$5"
  if known "$component" "$cve"; then
    return 0
  fi
  gh issue create \
    --title "[${component}] ${cve} — advisory triage" \
    --label "advisory,${tier},bundle:k8s-1.32,applicability:needs-review,cve:${cve}" \
    --body "$(cat <<EOF
Component: **${component}**  (tier ${tier})
CVE: **${cve}**
Source: ${source_url}

${summary}

This issue was opened automatically by \`.github/workflows/advisory-monitor.yml\`.
Triage workflow:

1. Confirm applicability per binary (see [docs/branching.md](../blob/main/docs/branching.md)).
2. If not-applicable, write a VEX entry in the release evidence and close.
3. If applicable, open a backport PR in \`oleksandr-minakov/kubernetes\` and link it here.

If marked KEV / actively-exploited, follow [docs/runbook-kev-hotfix.md](../blob/main/docs/runbook-kev-hotfix.md) instead of the monthly cadence.
EOF
    )" >/dev/null
  remember "$component" "$cve"
  echo "opened: $component / $cve"
}

extract_cves() {
  # Read stdin; print every distinct CVE-YYYY-NNNN it sees.
  grep -oE 'CVE-[0-9]{4}-[0-9]{4,7}' | sort -u
}

# KEV: a JSON document with vulnerabilities[]; filter to k8s mentions on the
# off-chance kubelet/apiserver show up directly. (KEV does NOT name internal
# kubernetes packages today, but defence-in-depth.)
poll_kev() {
  local url="$1"
  curl -fsSL --max-time 30 "$url" 2>/dev/null \
    | jq -r '.vulnerabilities[]? | select(.product | test("[Kk]ubernetes|kubelet|kube-")) | .cveID' \
    | sort -u
}

# Generic poll: just regex CVE IDs from the body.
poll_generic() {
  local url="$1"
  curl -fsSL --max-time 30 "$url" 2>/dev/null | extract_cves
}

for desc in components/*.yaml; do
  comp=$(yq -r '.name' "$desc")
  tier=$(yq -r '.tier' "$desc")
  src_count=$(yq -r '.advisory_sources | length' "$desc")
  for i in $(seq 0 $((src_count - 1))); do
    kind=$(yq -r ".advisory_sources[$i].kind" "$desc")
    url=$(yq -r ".advisory_sources[$i].url" "$desc")
    case "$kind" in
      kev)
        cves=$(poll_kev "$url")
        ;;
      *)
        cves=$(poll_generic "$url")
        ;;
    esac
    for cve in $cves; do
      open_issue "$comp" "$tier" "$cve" "$url" "Detected via ${kind} feed."
    done
  done
done

# Persist cursor back to main.
if [ -n "$(git status --porcelain "$state")" ]; then
  git config user.email "advisory-monitor@users.noreply.github.com"
  git config user.name  "advisory-monitor[bot]"
  git add "$state"
  git commit -m "advisory-monitor: cursor update"
  git push
fi
