#!/usr/bin/env bash
# Generate the (read-only) patch manifest for one stream from git + GitHub
# Issues, per §4 ("git+issues canonical, rendered to YAML").
#
# Inputs:
#   $1 — component
#   $2 — upstream_tag
#   $3 — lts_build
#   $4 — artifact ref (image digest or deb version)
#
# Output: YAML on stdout matching the schema example in the plan.
#
# This is a stub that emits a well-formed shell of the document. The real
# implementation walks `git log lts/<bundle>/<component-major-minor>` for
# commit trailers `LTS-Patch: CVE-XXXX-YYYY` and joins with GitHub issue
# state via `gh issue list --label cve --json`.
set -euo pipefail
component="${1:?component}"
upstream_tag="${2:?upstream_tag}"
lts_build="${3:?lts_build}"
artifact_ref="${4:?artifact_ref}"

cat <<EOF
# GENERATED — do not hand-edit (see scripts/render-patch-manifest.sh)
component: ${component}
stream: ${component}-1.32-lts.k8s-1.32
source_branch: release-1.32
upstream_tag: ${upstream_tag}
lts_build: ${lts_build}
artifacts:
  candidate: ${artifact_ref}
# Each patch entry below is derived from a commit trailer + an Issue.
# TODO(impl): replace this stub with the real git-log + gh-issues walker.
patches: []
EOF
