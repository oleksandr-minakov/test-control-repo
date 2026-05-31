#!/usr/bin/env bash
# Query the source fork for lts-tests check-runs at the tip of the LTS branch
# (v3 §9: source tests live in the fork and gate releases). Emits a JSON
# evidence file consumed by render-release-metadata.sh.
#
# Output:
#   {
#     "status": "passed" | "failed_or_missing",
#     "fork":   "<owner>/<repo>",
#     "branch": "lts/k8s-1.32/kubernetes-1.32",
#     "commit": "<sha>",
#     "checks": [{ name, conclusion, completed_at }, ...]
#   }
set -euo pipefail

fork= ; branch= ; out=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fork)   fork="$2"; shift 2;;
    --branch) branch="$2"; shift 2;;
    --out)    out="$2"; shift 2;;
    *) echo "fetch-source-tests: unknown arg $1" >&2; exit 2;;
  esac
done
[[ -z "$fork$branch$out" ]] && { echo "fetch-source-tests: --fork --branch --out required" >&2; exit 2; }

mkdir -p "$(dirname "$out")"

# Resolve the branch tip SHA.
SHA=$(gh api "repos/${fork}/branches/${branch}" --jq '.commit.sha' 2>/dev/null) \
  || { echo "fetch-source-tests: cannot resolve ${fork}#${branch}" >&2; exit 1; }

# Pull all check-runs at that SHA. lts-tests emits jobs named:
#   "unit (<component>)" — one per matrix entry
#   "build (compile-check all six)"
CHECKS=$(gh api "repos/${fork}/commits/${SHA}/check-runs" --paginate \
  --jq '[.check_runs[] | select((.name | startswith("unit (")) or (.name | startswith("build (compile-check"))) | {name, conclusion, status, completed_at}]')

# Status logic:
#   - all relevant checks must have conclusion=="success"
#   - there must be at least one (zero checks = "missing", fails gate)
GREEN=$(jq 'length > 0 and all(.[]; .conclusion == "success")' <<<"$CHECKS")

if [ "$GREEN" = "true" ]; then
  STATUS="passed"
else
  STATUS="failed_or_missing"
fi

jq -n \
  --arg status "$STATUS" \
  --arg fork "$fork" --arg branch "$branch" --arg sha "$SHA" \
  --argjson checks "$CHECKS" \
  '{status: $status, fork: $fork, branch: $branch, commit: $sha, checks: $checks}' \
  > "$out"

N=$(jq 'length' <<<"$CHECKS")
echo "fetch-source-tests: ${STATUS} for ${fork}#${branch}@${SHA:0:12} (${N} checks)"
