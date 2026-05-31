#!/usr/bin/env bash
# Assemble release-metadata.json from real evidence on disk.
#
# Args:
#   $1 — component name
#   $2 — evidence directory (created if absent)
#   $3 — findings JSON path (from _reusable-scan.yml)
#   $4 — SBOM JSON path (from _reusable-sbom.yml)
#
# Env (set by the caller workflow):
#   UPSTREAM_TAG, LTS_BUILD, BUNDLE, TIER, TARGET_KIND, TARGET_REF
#
# What it does NOT do:
#   * Verify cosign signatures (sign step runs AFTER evidence assembly so the
#     image/blob is only signed once the policy gate has its inputs). The
#     gate checks that the descriptor records the signing intent; the sign
#     step then enforces it. We mark signatures.image="pending" and the
#     workflow re-asserts "signed" after the sign job has produced its
#     artifact (see the policy in policy/signature.rego — "signed" or
#     "pending-with-sign-job" both pass; "unsigned" fails).
set -euo pipefail

component="${1:?component}"
ev="${2:?evidence dir}"
findings="${3:?findings path}"
sbom="${4:?sbom path}"

mkdir -p "$ev"

# Severity counts derived from the merged findings file.
if [ -s "$findings" ]; then
  crit=$(jq '.summary.critical // 0' "$findings")
  high=$(jq '.summary.high // 0'     "$findings")
  med=$(jq  '.summary.medium // 0'   "$findings")
  low=$(jq  '.summary.low // 0'      "$findings")
else
  crit=0; high=0; med=0; low=0
fi

# CPE coverage check (true if verify-cpe-coverage already passed; else "incomplete").
if [ -s "$sbom" ]; then
  if "$(dirname "$0")/verify-cpe-coverage.sh" "$sbom" >/dev/null 2>&1; then
    cpe_cov="complete"
  else
    cpe_cov="incomplete"
  fi
else
  cpe_cov="incomplete"
fi

# VEX scaffold — real entries land here when AI triage + human confirm
# complete (§8). The scaffold exists so the gate doesn't false-fail on first run.
vex="$ev/vex.cdx.json"
if [ ! -f "$vex" ]; then
  cat > "$vex" <<EOF
{"bomFormat":"CycloneDX","specVersion":"1.5","version":1,"vulnerabilities":[]}
EOF
fi

# SLSA L2 provenance scaffold; real predicate is built into the attestation
# by cosign in the sign step. The scaffold here is what gets *attached*.
prov="$ev/provenance.intoto.jsonl"
if [ ! -f "$prov" ]; then
  jq -n \
    --arg name "$component" \
    --arg ref  "${TARGET_REF:-}" \
    --arg tag  "${UPSTREAM_TAG:-}" \
    --arg bundle "${BUNDLE:-}" \
    --arg build "${LTS_BUILD:-}" \
    '{
       "_type":"https://in-toto.io/Statement/v1",
       "predicateType":"https://slsa.dev/provenance/v1",
       "subject":[{name:$name, digest:{ref:$ref}}],
       "predicate":{
         buildDefinition:{
           buildType:"https://github.com/oleksandr-minakov/test-control-repo/build-image@v1",
           externalParameters:{upstream_tag:$tag, lts_build:$build, bundle:$bundle}
         },
         runDetails:{builder:{id:(env.GITHUB_SERVER_URL + "/" + env.GITHUB_REPOSITORY + "/actions/runs/" + env.GITHUB_RUN_ID)}}
       }
     }' > "$prov"
fi

# Coverage matrix — required_tests come from the descriptor. Under the
# release-cascade model source tests are enforced by branch protection on the
# source fork (PR → merge → tag). The build repo does NOT re-query their
# status; if a tag exists in the source fork, the cascade has already passed.
# The required/skipped lists are kept here as documentation that flows into
# the per-release coverage matrix.
required=$(yq -o=json -I=0 '.tests.upstream_targets' "components/${component}.yaml" 2>/dev/null || echo '[]')
skipped=$(yq -o=json -I=0 '.tests.skipped // []'      "components/${component}.yaml" 2>/dev/null || echo '[]')
license_clear=$(yq -r '.license.ga_blocker // false'  "components/${component}.yaml" 2>/dev/null \
                | awk '{print ($1=="true")?"false":"true"}')
ga_blocker=$(yq -r '.license.ga_blocker // false'     "components/${component}.yaml" 2>/dev/null)

# VEX required_entries = all critical+high finding CVEs (per §8 — every
# Crit/High must have a VEX justification before GA).
required_vex='[]'
if [ -s "$findings" ]; then
  required_vex=$(jq '[.findings[] | select(.severity=="critical" or .severity=="high") | .cve] | unique' "$findings")
fi

out="$ev/release-metadata.json"
jq -n \
  --arg component   "$component" \
  --arg tier        "${TIER:-tier-1}" \
  --arg bundle      "${BUNDLE:-k8s-1.32}" \
  --arg upstream    "${UPSTREAM_TAG:-}" \
  --argjson lts_build "${LTS_BUILD:-1}" \
  --arg target_kind "${TARGET_KIND:-image}" \
  --arg target_ref  "${TARGET_REF:-}" \
  --arg sbom_path   "$sbom" \
  --arg findings_path "$findings" \
  --argjson crit "$crit" --argjson high "$high" --argjson med "$med" --argjson low "$low" \
  --arg cpe_cov "$cpe_cov" \
  --argjson required_vex "$required_vex" \
  --argjson required "$required" \
  --argjson skipped "$skipped" \
  --argjson ga_blocker "${ga_blocker:-false}" \
  --argjson license_clear "${license_clear:-true}" \
  '{
    component: $component,
    tier: $tier,
    bundle: $bundle,
    upstream: $upstream,
    lts_build: $lts_build,
    artifact: { kind: $target_kind, ref: $target_ref },
    sbom: { format: "cyclonedx-json", path: $sbom_path, cpe_coverage: $cpe_cov },
    scan: { findings: $findings_path, critical: $crit, high: $high, medium: $med, low: $low },
    signatures: { image: "pending-sign-job", deb_blob: false, attestations: ["cyclonedx","vuln","slsaprovenance"] },
    vex: { path: "evidence/vex.cdx.json", required_entries: $required_vex, entries: [] },
    tests: {
      required_upstream: $required,
      skipped_upstream: $skipped,
      build_repo: { artifact_smoke: "n/a-cascade" }
    },
    license: { clear: $license_clear, ga_blocker: $ga_blocker },
    patch_manifest: "evidence/patch-manifest.yaml"
  }' > "$out"

echo "wrote $out"
