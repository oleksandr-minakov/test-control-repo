# Runbook — Monthly bundle release

Realises Appendix A of the plan. Owner: **Lead** (release approval). All
timings are relative to T-0 = GA promotion.

## T-10d — Triage freeze

- [ ] Lead announces freeze in `#lts-release`.
- [ ] All open advisory-monitor issues for k8s-core marked
      `applicability:<affected|not_affected|deferred>`. Anything still
      `needs-review` → scoped out of this bundle.
- [ ] Per-component patch queue snapshotted; commit trailers verified.

## T-7d — Candidate builds green

- [ ] `lts-tests.yml` on the fork is green at the head of
      `lts/k8s-1.32/kubernetes-1.32` (v3 §9 source-layer gate).
- [ ] Each of the six `component-*` workflows has a green run on the head
      of `lts/k8s-1.32/kubernetes-1.32`.
- [ ] SBOM, signatures, attestations, patch manifest, release metadata
      artifacts exist for every candidate.
- [ ] Counts (`scan.summary.critical`, `.high`) reviewed by Lead.

## T-5d — Bundle integration smoke

- [ ] `bundle-release.yml` triggered manually with the release tag (e.g.
      `2026.06`).
- [ ] `collect-bundle-streams.sh` produces `bundle-manifest.json`.
- [ ] `bundle-smoke.sh` returns OK on the kind cluster (apiserver healthz,
      scheduler placement, kube-proxy ClusterIP).
- [ ] If failure: scope back, do not stretch the gate.

## T-3d — Release-readiness review

- [ ] OPA policy gate green for every component **and** the bundle.
- [ ] Coverage matrix (per-stream `tests.skipped_upstream`) reviewed and
      attached to the release.
- [ ] Evidence bundle assembled and uploaded.

## T-1d — Customer advisory

- [ ] Draft customer advisory distinguishing **awareness / applicability /
      fix availability / rollout** (§7). Rollout language explicitly
      customer-owned.
- [ ] Lead + Eng reviewer sign off.

## T-0 — GA promotion

- [ ] `promote-bundle.sh` opens the `release/k8s-1.32-lts.YYYY.MM` PR.
- [ ] Lead approves via CODEOWNERS. PR merged → publish step:
      images promoted (tags repointed at GA digests), debs published to the
      `k8s-1.32-lts` suite.
- [ ] Stream files updated: `status: candidate → ga`, `oci_digest` /
      `deb_version` set.
- [ ] Bundle manifest tagged `k8s-1.32-lts.YYYY.MM` in git.

## Hotfix exception

If a KEV/actively-exploited CVE lands between bundles, follow
`runbook-kev-hotfix.md` instead.
