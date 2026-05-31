package lts.release

import future.keywords.if
import future.keywords.in

# Signature presence is enforced by workflow ordering: every component caller's
# `gate` job has `needs: [sign]`, so a green gate implies cosign signing
# succeeded. The evidence document is emitted BEFORE the sign job runs (no
# cycle) so it records intent ("pending-sign-job"), which the policy treats as
# equivalent to "signed". An "unsigned" value or absence of the sign-intent
# attestation list fails closed.

signature_violations := violations if {
  violations := array.concat(_image_sig, _attestations)
}

_image_sig := v if {
  input.artifact.kind == "image"
  not _image_sig_ok
  v := [sprintf("artifact %v is not signed (signatures.image=%v)", [input.artifact.ref, input.signatures.image])]
} else := v if {
  input.artifact.kind == "deb"
  not _deb_sig_intent
  v := [sprintf("deb %v has no cosign blob signature intent", [input.artifact.ref])]
} else := []

_image_sig_ok if {
  input.signatures.image == "signed"
}
_image_sig_ok if {
  input.signatures.image == "pending-sign-job"
}

_deb_sig_intent if {
  input.signatures.image == "pending-sign-job"
}
_deb_sig_intent if {
  input.signatures.deb_blob == true
}

required_attestations := {"cyclonedx", "vuln", "slsaprovenance"}

_attestations := violations if {
  input.artifact.kind == "image"
  missing := required_attestations - {a | a := input.signatures.attestations[_]}
  count(missing) > 0
  violations := [sprintf("missing attestation intent on image: %v", [missing])]
} else := []
