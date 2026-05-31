package lts.release

import future.keywords.if

sbom_violations := v if {
  not input.sbom.path
  v := ["SBOM missing from release metadata"]
} else := v if {
  input.sbom.format != "cyclonedx-json"
  v := [sprintf("SBOM format must be cyclonedx-json, got %v", [input.sbom.format])]
} else := v if {
  input.sbom.cpe_coverage != "complete"
  v := [sprintf("SBOM CPE coverage incomplete (%v) — see §8/§9 scanner-lag mitigation", [input.sbom.cpe_coverage])]
} else := []
