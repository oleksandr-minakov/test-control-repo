#!/usr/bin/env bash
# Read a component descriptor and emit its fields as GHA $GITHUB_OUTPUT lines.
# Best-effort schema validation if check-jsonschema is on PATH; otherwise the
# yq emit step will fail-fast on broken YAML.
set -euo pipefail

desc="${1:?descriptor path required}"
schema="$(dirname "$0")/../components/_schema.json"

if command -v check-jsonschema >/dev/null 2>&1; then
  check-jsonschema --schemafile "$schema" "$desc" >&2 || {
    echo "load-descriptor: schema validation failed for $desc" >&2; exit 1; }
else
  echo "load-descriptor: check-jsonschema not present; skipping schema validation" >&2
fi

# yq v4 (mikefarah/yq) is preinstalled on ubuntu-latest GHA runners.
yq -r '
  "upstream_tag=" + .upstream.tag,
  "bundle="          + (.fork.lts_branch | sub("^lts/"; "") | sub("/.*"; "")),
  "fork_repo="       + .fork.repo,
  "lts_branch="      + .fork.lts_branch,
  "toolchain_image=" + .build.toolchain_image,
  "base_image="      + ((.distribution.oci.base_image)    // ""),
  "registry_path="   + ((.distribution.oci.registry_path) // ""),
  "entrypoint="      + .build.entrypoint,
  "tier="            + .tier,
  "package_name="    + ((.distribution.deb.package_name) // ""),
  "maintainer="      + ((.distribution.deb.maintainer)   // "")
' "$desc"
