#!/usr/bin/env bash
# Post open advisory-monitor issues to the bounded AI triage agent. The agent
# returns proposed VEX status + cherry-pick feasibility, posted as an issue
# comment. NO autonomous merges/promotions — humans confirm (§8).
set -euo pipefail

[ -n "${AI_TRIAGE_ENDPOINT:-}" ] || { echo "ai-triage: AI_TRIAGE_ENDPOINT unset; skipping"; exit 0; }

gh issue list --label advisory --label "applicability:needs-review" --json number,title,body \
  | jq -c '.[]' \
  | while read -r issue; do
      num=$(jq -r '.number' <<<"$issue")
      payload=$(jq -n --argjson i "$issue" '{issue:$i, instructions:"Per ai-agent-integration.md: propose VEX status + cherry-pick feasibility. Do NOT close issues, do NOT open backport PRs autonomously."}')
      resp=$(curl -fsSL -X POST "$AI_TRIAGE_ENDPOINT" \
        -H "Authorization: Bearer ${AI_TRIAGE_TOKEN}" \
        -H 'Content-Type: application/json' \
        -d "$payload" || echo '{"error":"triage endpoint unreachable"}')
      gh issue comment "$num" --body "$(jq -r '"AI triage (first-pass):\n\n```json\n" + (. | tostring) + "\n```\n\nHuman review required before any merge/promotion."' <<<"$resp")" >/dev/null
    done
