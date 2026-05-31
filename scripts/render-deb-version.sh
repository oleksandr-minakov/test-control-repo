#!/usr/bin/env bash
# Render the apt-ordered deb version per §5.
#
# Inputs:
#   $1 — upstream tag, e.g. v1.32.13
#   $2 — LTS build number, e.g. 1
#
# Emits:
#   deb_version=1.32.13-1~lts1
#
# apt ordering (verified with `dpkg --compare-versions`):
#     1.32.13-1            (hypothetical upstream)
#   < 1.32.13-1~lts1     (our first LTS rebuild)
#   < 1.32.13-1~lts2
#   < 1.32.13-2            (a real future upstream re-pack)
#
# The `~ltsN` suffix is monotonically increasing and never "borrows" the
# next upstream version number.
set -euo pipefail

upstream_tag="${1:?upstream_tag required}"
lts_build="${2:?lts_build required}"

if [[ ! "$upstream_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "render-deb-version: upstream tag must be vMAJOR.MINOR.PATCH, got '${upstream_tag}'" >&2
  exit 1
fi
canonical="${upstream_tag#v}"
if [[ ! "$lts_build" =~ ^[0-9]+$ ]] || [[ "$lts_build" -lt 1 ]]; then
  echo "render-deb-version: lts_build must be a positive integer, got '${lts_build}'" >&2
  exit 1
fi

echo "deb_version=${canonical}-1~lts${lts_build}"
