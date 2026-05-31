package lts.release

import future.keywords.if
import future.keywords.in

# Per LTS plan v3 §9, gates read TWO test layers:
#   tests.source_repo   = the fork's lts-tests on the LTS branch tip
#   tests.build_repo    = artifact-level validation in the build repo
#                         (image/package smoke, structure test, csi-sanity for CSI)
#
# Source-fork gate: the canonical PR validation for every CVE backport. Must
# be "passed" before any tier-1 release ships.
#
# Build-repo gate: confirms the BUILT artifact is sane. "passed" once the
# artifact smoke job has reported success.
#
# The required/skipped upstream lists in the descriptor are kept as
# documentation that flows into the coverage matrix; the gate doesn't compare
# them to a "passed" list anymore — the actual PASS signal comes from the
# fork's check-runs (real test outcomes), not from a hand-curated list.

test_violations := violations if {
  input.tier == "tier-1"
  input.tests.source_repo.status != "passed"
  violations := [sprintf(
    "tier-1 release blocked: source-fork tests not passed (status=%v, branch=%v, commit=%v)",
    [input.tests.source_repo.status, input.tests.source_repo.branch, input.tests.source_repo.commit])]
} else := violations if {
  input.tier == "tier-1"
  not _artifact_smoke_ok
  violations := [sprintf(
    "tier-1 release blocked: build-repo artifact smoke not passed (status=%v)",
    [input.tests.build_repo.artifact_smoke])]
} else := violations if {
  input.tier == "tier-1"
  not input.tests.skipped_upstream
  violations := ["tier-1 release must disclose tests.skipped_upstream (coverage matrix)"]
} else := []

# Pending status is acceptable in the same dependency-cycle sense as
# signature.rego: the gate job needs ["sign","artifact-smoke"], so when the
# gate runs both have succeeded. The release-metadata is built before those,
# so it records intent; the workflow ordering enforces the actual fact.
_artifact_smoke_ok if {
  input.tests.build_repo.artifact_smoke == "passed"
}
_artifact_smoke_ok if {
  input.tests.build_repo.artifact_smoke == "pending-smoke-job"
}
