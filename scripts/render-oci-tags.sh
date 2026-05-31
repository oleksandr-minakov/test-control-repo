#!/usr/bin/env bash
# Render OCI tags from (upstream_tag, lts_build) per §5.
#
# Inputs:
#   $1 — upstream tag, e.g. v1.32.13
#   $2 — LTS build number, e.g. 1
#
# Emits GHA-style key=value lines for $GITHUB_OUTPUT:
#   canonical=1.32.13
#   human=1.32.13-lts1
#
# The canonical tag matches upstream version (mutable across rebuilds — pin
# consumers by digest). The human tag is stable, legal-OCI, and lexically
# sortable. SemVer pre-release and +build forms are explicitly rejected (§5).
set -euo pipefail

upstream_tag="${1:?upstream_tag required (e.g. v1.32.13)}"
lts_build="${2:?lts_build required (integer)}"

# Validate: upstream_tag must be vMAJOR.MINOR.PATCH (the v prefix is required —
# the rest of the system uses it consistently).
if [[ ! "$upstream_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "render-oci-tags: upstream tag must be vMAJOR.MINOR.PATCH, got '${upstream_tag}'" >&2
  exit 1
fi
canonical="${upstream_tag#v}"

if [[ ! "$lts_build" =~ ^[0-9]+$ ]] || [[ "$lts_build" -lt 1 ]]; then
  echo "render-oci-tags: lts_build must be a positive integer, got '${lts_build}'" >&2
  exit 1
fi

echo "canonical=${canonical}"
echo "human=${canonical}-lts${lts_build}"
