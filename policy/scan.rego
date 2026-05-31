package lts.release

import future.keywords.if
import future.keywords.in

# Findings must be attached. Critical/High counts must reconcile against VEX:
# the gate does NOT auto-fail on any Crit/High — that would force-fail releases
# where the finding is justifiably not_affected. Instead, every Crit/High must
# have a corresponding VEX entry (handled in vex.rego). The scan rule here just
# enforces presence + machine-readability of the merged findings file.

scan_violations := v if {
  not input.scan.findings
  v := ["scan findings not attached to release metadata"]
} else := v if {
  input.scan.critical == null
  v := ["scan.critical count missing"]
} else := v if {
  input.scan.high == null
  v := ["scan.high count missing"]
} else := []
