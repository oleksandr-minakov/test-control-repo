# Top-level release-readiness gate. Composes the per-aspect rules in this
# directory and emits violations consumed by Conftest.
#
# Expected document shape (release-metadata.json):
#   {
#     "component":   "kube-apiserver",
#     "tier":        "tier-1",
#     "bundle":      "k8s-1.32",
#     "upstream":    "v1.32.13",
#     "lts_build":   1,
#     "artifact":    {"kind": "image", "ref": "...@sha256:..."},
#     "sbom":        {"format": "cyclonedx-json", "path": "...", "cpe_coverage": "complete"},
#     "scan":        {"findings": "scans/findings.json", "critical": 0, "high": 0},
#     "signatures":  {"image": "signed", "attestations": ["cyclonedx","vuln","slsaprovenance"]},
#     "vex":         {"path": "evidence/vex.cdx.json", "required_entries": [...]},
#     "tests":       {"required": [...], "passed": [...], "skipped_upstream": [...]},
#     "license":     {"clear": true, "ga_blocker": false},
#     "patch_manifest": "evidence/patch-manifest.yaml"
#   }

package lts.release

import future.keywords.if
import future.keywords.in
import future.keywords.contains

deny contains msg if {
  some r in required_rules
  msg := r
}

required_rules := array.concat(
  array.concat(
    array.concat(signature_violations, sbom_violations),
    array.concat(scan_violations, vex_violations),
  ),
  array.concat(test_violations, license_violations),
)
