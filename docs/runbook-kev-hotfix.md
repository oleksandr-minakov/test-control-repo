# Runbook — KEV hotfix (fast-track exception)

Realises Appendix B of the plan. Used when a CVE is on CISA KEV or actively
exploited; **bypasses** the monthly bundle cadence but **not** the gates.

## T+0h — Detection

- [ ] `advisory-monitor` fires, OR Core Assurance pages the LTS team, OR a
      customer scanner finding maps to a Tier-1 stream.
- [ ] Lead declares P1 on `#lts-incident`.

## T+1h — Applicability

- [ ] AI triage first-pass posted as Issue comment.
- [ ] Human confirms applicability per-binary (one Issue per CVE×component;
      a single upstream commit may touch only one of the six).
- [ ] If `not_affected`: write VEX entry, close, exit runbook.

## T+4h — Backport PR open

- [ ] Engineer creates `backport/<CVE>/lts-k8s-1.32-kubernetes-1.32`.
- [ ] Cherry-pick or re-implement. Note strategy in PR description.
- [ ] Source-native tests running.

## T+24h — Review + merge (Tier 1 → two-person)

- [ ] Two engineers review. Non-clean cherry-picks require the second review.
- [ ] Merge to `lts/k8s-1.32/kubernetes-1.32`. Commit trailer
      `LTS-Patch: <CVE>` present.

## T+36h — Hermetic build, SBOM, scan, sign

- [ ] Trigger the affected `component-*` workflows with `lts_build: <prev+1>`.
- [ ] All artifacts pass the gate; release metadata assembled.

## T+48h — GA hotfix promotion

- [ ] `bundle-release.yml` triggered with tag `YYYY.MM.hotfix.N`.
- [ ] `bundle-smoke.sh` green on the hotfix manifest.
- [ ] Lead approval merges the release PR; publish runs.
- [ ] Stream files updated.
- [ ] Customer advisory published distinguishing awareness / applicability /
      fix availability / rollout.

Customer rollout is **customer-owned** from this point.
