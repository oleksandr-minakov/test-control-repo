package lts.release

import future.keywords.if
import future.keywords.in

# Per §8: VEX must be present on every artifact. Every Critical/High finding
# from the merged scan must have a VEX entry (one of: affected, not_affected,
# fixed, under_investigation). Releases cannot ship with under_investigation
# entries unless the finding is below tier threshold.

vex_violations := violations if {
  not input.vex.path
  violations := ["VEX document missing"]
} else := violations if {
  count(input.vex.required_entries) > 0
  missing := [c | c := input.vex.required_entries[_]; not _has_vex_entry(c)]
  count(missing) > 0
  violations := [sprintf("missing VEX entries for: %v", [missing])]
} else := violations if {
  blockers := [c |
    c := input.vex.entries[_]
    c.status == "under_investigation"
    c.severity == "critical"
  ]
  count(blockers) > 0
  violations := [sprintf("Critical findings under_investigation block GA: %v", [[b.cve | b := blockers[_]]])]
} else := []

_has_vex_entry(cve) if {
  some entry in input.vex.entries
  entry.cve == cve
  entry.status != ""
}
