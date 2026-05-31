package lts.release

import future.keywords.if
import future.keywords.in

# Required tests per tier (§3/§9). Bucket-A targets must be present + passing
# for every tier-1 release. Bucket-B targets are required only if listed in
# the descriptor's tests.upstream_targets. Skipped upstream signal must be
# disclosed in tests.skipped_upstream — that's how the per-release coverage
# matrix (§9) becomes part of the release evidence.

test_violations := violations if {
  required := {t | t := input.tests.required[_]}
  passed   := {t | t := input.tests.passed[_]}
  missing  := required - passed
  count(missing) > 0
  violations := [sprintf("required tests not green: %v", [missing])]
} else := violations if {
  input.tier == "tier-1"
  not input.tests.skipped_upstream
  violations := ["tier-1 release must disclose tests.skipped_upstream (coverage matrix)"]
} else := []
