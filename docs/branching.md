# Branching for the `kubernetes/kubernetes` fork

Per §4, one private fork holds source for all six k8s-core components. Six
components share **one LTS branch** because they all build from the same
upstream source tree; per-binary applicability is decided in the patch
manifest, not by separating branches.

## Branch names

| Branch                                | Purpose                                                       |
|---------------------------------------|---------------------------------------------------------------|
| `upstream/main`                       | Mirror of upstream `master`. **Never patched.**               |
| `upstream/release-1.32`               | Mirror of upstream `release-1.32`. Never patched.             |
| `lts/k8s-1.32/kubernetes-1.32`        | **The** LTS branch for all six components in the bundle.      |
| `backport/<CVE>/lts-k8s-1.32-kubernetes-1.32` | Working branch for a single backport PR.              |
| `core-assurance/INC-<ID>/lts-k8s-1.32-kubernetes-1.32` | Working branch for a Core Assurance incident fix. |

## Cutting the LTS branch

```
git fetch upstream
git checkout -b lts/k8s-1.32/kubernetes-1.32 v1.32.13
git push origin lts/k8s-1.32/kubernetes-1.32
```

The init script in the source-fork tree (`scripts/lts-branch-init.sh`) does
exactly this and is idempotent.

## Sync cadence (§4)

| Tier 1 (Core) | Daily metadata check, weekly mirror sync of `upstream/release-1.32`. |

We **never** merge `upstream/*` into the LTS branch. The LTS branch receives
**cherry-picks** from upstream onto a fresh `backport/<CVE>/...` branch, which
then opens a PR against the LTS branch.

## Backport workflow (v3)

1. Triage decides applicability (§2 step 4–5). One Issue per CVE×component.
2. Engineer creates `backport/<CVE>/lts-k8s-1.32-kubernetes-1.32` from
   `lts/k8s-1.32/kubernetes-1.32`.
3. Cherry-pick upstream fix(es). If non-clean, record the strategy
   (`reimplemented` | `partial` | `dropped`) in the PR description.
4. **PR runs `lts-tests.yml` on the fork** — upstream unit tests for each
   component + a six-binary compile-check. This is the canonical validation
   of the patch (v3 §9 layer 1). Tier-1 non-clean → **two-person review**
   (CODEOWNERS-enforced).
5. Merge. Add a commit trailer `LTS-Patch: CVE-XXXX-YYYY`; the patch-manifest
   generator (`scripts/render-patch-manifest.sh`) consumes it.
6. The build repo's `component-<X>.yml` then runs hermetic build +
   artifact-level validation (v3 §9 layer 2). Its gate checks that
   `lts-tests` on the fork was green at the merged commit; if not, the
   release is blocked.
