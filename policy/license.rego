package lts.release

import future.keywords.if

# Per §8 onboarding checklist: components flagged as GA-blockers cannot reach
# GA until the legal box is cleared. The descriptor's license.ga_blocker drives
# this; the gate refuses to promote any candidate whose component still carries
# the flag.

license_violations := v if {
  input.license.ga_blocker == true
  v := [sprintf("component %v has license.ga_blocker=true (onboarding checklist not cleared)", [input.component])]
} else := v if {
  input.license.clear == false
  v := [sprintf("component %v license not cleared", [input.component])]
} else := []
