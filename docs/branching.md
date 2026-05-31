# Branching — Mirantis release-cascade for `kubernetes/kubernetes`

Under the cascade, the source fork holds **one** working branch per minor
line: `release-1.32`. release-please cuts tags from that branch, and the
cross-repo bump PR updates `VERSION` in this build repo. Six core
components share a single source tree because they all build from the same
upstream; per-binary patch applicability lives in the patch manifest, not
in separate branches.

## Branches on the source fork

| Branch                                                | Purpose                                                       |
|-------------------------------------------------------|---------------------------------------------------------------|
| `upstream/main`                                       | Mirror of upstream `master`. **Never patched.**               |
| `upstream/release-1.32`                               | Mirror of upstream `release-1.32`. **Never patched.**         |
| `release-1.32`                                        | **The** Mirantis LTS release line for 1.32. Protected; lts-tests required. |
| `backport/<CVE>/release-1.32`                         | Working branch for a single CVE backport PR.                  |
| `core-assurance/INC-<ID>/release-1.32`                | Working branch for a Core Assurance incident fix.             |

## Cutting `release-1.32`

```
git fetch upstream
git checkout -b release-1.32 v1.32.13
git push origin release-1.32
```

Then in the GitHub UI: enable branch protection on `release-1.32` requiring
the `lts-tests` status check, and require PRs (no direct pushes).

## Sync cadence

| Tier 1 (Core) | Daily metadata check; weekly mirror sync of `upstream/release-1.32`. |

`upstream/*` is **never** merged into `release-1.32`. The release line
receives **cherry-picks** from upstream onto a fresh `backport/<CVE>/...`
branch, which then opens a PR against `release-1.32`.

## Backport workflow

1. Triage decides applicability. One Issue per CVE×component.
2. Engineer creates `backport/<CVE>/release-1.32` from `release-1.32`.
3. Cherry-pick upstream fix(es). If non-clean, record the strategy
   (`reimplemented` | `partial` | `dropped`) in the PR description.
4. **PR runs `mirantis_release.yaml`** (alias: lts-tests) on the fork —
   upstream unit tests for each component + a six-binary compile-check.
   Branch protection makes this required. Tier-1 non-clean →
   **two-person review** (CODEOWNERS-enforced).
5. Merge. Add a commit trailer `LTS-Patch: CVE-XXXX-YYYY`; the
   patch-manifest generator (`scripts/render-patch-manifest.sh`) consumes
   it.
6. release-please observes the merge, opens / advances a release PR (bumps
   `version.txt`, appends to `CHANGELOG.md`). Merging the release PR cuts
   tag `vX.Y.Z-lts.N` on `release-1.32` **and** opens a cross-repo PR
   against the build repo updating `VERSION`.
7. Merging the bump PR in the build repo triggers `build.yaml`. The build
   does **not** re-fetch test status: by the time a tag exists, branch
   protection has already enforced it.
