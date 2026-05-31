#!/usr/bin/env bash
# Open a PR pinning the bundle manifest to specific candidate digests.
# Per §2 flow step 13: GA promotion is human-approved (the PR).
set -euo pipefail

manifest= ; release_tag=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)    manifest="$2"; shift 2;;
    --release-tag) release_tag="$2"; shift 2;;
    *) echo "promote-bundle: unknown arg $1" >&2; exit 2;;
  esac
done

branch="release/k8s-1.32-lts.${release_tag}"
git checkout -b "$branch"
cp "$manifest" "bundles/releases/k8s-1.32-lts.${release_tag}.json"
git add "bundles/releases/k8s-1.32-lts.${release_tag}.json"
git -c user.email="lts-bot@example.com" \
    -c user.name="LTS Release Bot" \
    commit -m "Release k8s-1.32-lts.${release_tag}"
git push -u origin "$branch"

gh pr create \
  --base main --head "$branch" \
  --title "Release k8s-1.32-lts.${release_tag}" \
  --body "Promotes candidate digests in \`bundles/releases/k8s-1.32-lts.${release_tag}.json\`.

Requires Lead approval (CODEOWNERS) and a green OPA gate.

See docs/runbook-monthly-bundle.md for the pre-merge checklist."
