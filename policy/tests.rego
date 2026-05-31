package lts.release

import future.keywords.if
import future.keywords.in

# Under the Mirantis release-cascade flow, source-test status is enforced
# upstream by branch protection on PR → merge → tag. The build repo never
# re-queries it; this gate just validates artifact-level evidence.
#
# Concretely:
#   * In the source fork, lts-tests must pass for the PR to merge into the
#     release-* branch (branch protection).
#   * release-please then cuts a tag from that protected branch.
#   * The cross-repo bump PR updates VERSION here, build.yaml fires, the
#     artifacts (image / deb) plus their SBOM, scan, and signing evidence
#     are produced.
#
# That means the only test-related claim this rego still has to assert is
# coverage-matrix disclosure: tier-1 releases must publish the list of
# upstream signals they knowingly skip, so consumers can audit it.

test_violations := violations if {
  input.tier == "tier-1"
  not input.tests.skipped_upstream
  violations := ["tier-1 release must disclose tests.skipped_upstream (coverage matrix)"]
} else := []
