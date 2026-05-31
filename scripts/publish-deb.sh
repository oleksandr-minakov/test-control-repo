#!/usr/bin/env bash
# Add a .deb to the signed deb repository and re-sign Release. Uses aptly on
# the deb-repo host. Repository signing key is in Vault transit (DEB_REPO_KEY_REF).
set -euo pipefail

deb= ; suite= ; component=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --deb)       deb="$2"; shift 2;;
    --suite)     suite="$2"; shift 2;;
    --component) component="$2"; shift 2;;
    *) echo "publish-deb: unknown arg $1" >&2; exit 2;;
  esac
done
[[ -z "$deb$suite$component" ]] && { echo "publish-deb: --deb, --suite, --component required" >&2; exit 2; }
[ -f "$deb" ] || { echo "publish-deb: file not found: $deb" >&2; exit 1; }

# TODO(infra-setup.md#deb-repo-signing): wire to the real aptly host. The shape
# below documents the intended steps so the runbook is concrete.
echo "publish-deb: would run on \$DEB_REPO_HOST via ssh:"
cat <<EOF
  aptly repo add ${suite}-${component} ${deb}
  aptly publish update \\
    -batch \\
    -gpg-provider=external \\
    -gpg-key="${DEB_REPO_KEY_REF}" \\
    ${suite}
EOF
