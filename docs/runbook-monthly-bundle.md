# Runbook — Monthly bundle release

Realises Appendix A of the plan, adapted to the Mirantis release cascade.
Owner: **Lead** (release approval). All timings relative to T-0 = GA
promotion.

## T-10d — Triage freeze

- [ ] Lead announces freeze in `#lts-release`.
- [ ] All open advisory-monitor issues for k8s-core marked
      `applicability:<affected|not_affected|deferred>`. Anything still
      `needs-review` → scoped out of this bundle.
- [ ] Per-component patch queue snapshotted; commit trailers verified.

## T-7d — Cascade green for the candidate tag

- [ ] All required backport PRs merged into source fork `release-1.32`
      (branch protection guarantees `lts-tests` was green on each one).
- [ ] release-please's release PR for the cycle's `vX.Y.Z-lts.N` has been
      reviewed and merged → tag exists on `release-1.32`.
- [ ] The cross-repo bump PR has landed on this repo's `release-1.32`
      branch, updating `VERSION`.
- [ ] `build.yaml` has a green run on that bump commit. All six components
      produced artifacts:
      * 4 images on `ghcr.io/oleksandr-minakov/lts-k8s/*`
      * 2 deb artifacts uploaded to the run
- [ ] SBOM, scan findings, cosign signatures + attestations exist for every
      artifact.
- [ ] Counts (`scan.summary.critical`, `.high`) reviewed by Lead.

## T-5d — Bundle integration smoke

- [ ] `bundles/` manifest reviewed; `scripts/collect-bundle-streams.sh`
      produces `bundle-manifest.json` from the published images.
- [ ] Manual kind smoke on the four image tags: apiserver `/healthz`,
      scheduler placement, kube-proxy ClusterIP routing.
- [ ] If failure: scope back, do not stretch the gate.

## T-3d — Release-readiness review

- [ ] OPA policy gate green per component (now artifact-level only — the
      cascade has already gated tests).
- [ ] Coverage matrix (per-stream `tests.skipped_upstream`) reviewed and
      attached to the release.
- [ ] Evidence bundle assembled and uploaded.

## T-1d — Customer advisory

- [ ] Draft customer advisory distinguishing **awareness / applicability /
      fix availability / rollout**. Rollout language explicitly
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
`runbook-kev-hotfix.md` instead. The cascade still applies — the only
difference is the release-please PR is merged out-of-band on a
hotfix-priority basis.
