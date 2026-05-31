# Versioning — k8s-core on the Mirantis release cascade

Under the cascade, the canonical version is the **tag on the source fork's
release branch**, produced by release-please. Format:

```
vX.Y.Z-lts.N      e.g. v1.32.13-lts.0   (initial), v1.32.13-lts.1, ...
```

- `X.Y.Z` is the upstream point release the LTS branch is based on.
- `-lts.N` is the Mirantis LTS revision, incremented on every release
  (CVE backport, hotfix, etc.) cut from the same upstream base.

The leading `v` is **canonical** in the tag and in `VERSION`. `build.sh`
strips it for the deb `Version:` field and for image tags.

## Where it lives

| Location                                  | Contents                  | Updated by                                |
|-------------------------------------------|---------------------------|-------------------------------------------|
| Source fork `version.txt`                 | `vX.Y.Z-lts.N`            | release-please                            |
| Source fork tag                           | `vX.Y.Z-lts.N`            | release-please                            |
| Build repo `VERSION` (this file)          | `vX.Y.Z-lts.N`            | release-please-action cross-repo bump PR  |

The cross-repo bump PR is what triggers `build.yaml` (it touches `VERSION`
on a `release-*` branch).

## Per-transport rendering at build time

| Transport | What `build.sh` produces                                                  |
|-----------|---------------------------------------------------------------------------|
| OCI image | tag `X.Y.Z-lts.N` + `candidate-<GITHUB_RUN_ID>` + immutable digest        |
| Deb       | `Version: X.Y.Z-lts.N` (leading `v` stripped)                             |
| OCI labels| `net.lts.{component, tag, bundle, source-repo}` set inside the Dockerfile |

The bundle label is derived from the upstream minor: `1.32.13-lts.0` →
`net.lts.bundle=k8s-1.32`.

## Things explicitly NOT used

- SemVer pre-release matching (`1.32.13-lts.1` sorts **below** `1.32.13` for
  SemVer-strict consumers — that's fine, we don't use SemVer ranges).
- `+build` metadata — illegal in OCI tags.
- A separate "human" tag scheme. The cascade gives us one canonical string;
  we use it everywhere.

## Bundle release tag

`k8s-1.32-lts.YYYY.MM` (+ `.hotfix.N` for KEV fast-track). The bundle tag
is independent of the per-component cascade tag and continues to be set by
the monthly release runbook.

## When upstream releases `v1.32.14`

1. On the source fork, fast-forward `release-1.32` to incorporate the new
   upstream point release (cherry-picks or a controlled merge — see
   branching.md).
2. release-please's next release PR will propose `v1.32.14-lts.0`.
3. Merge it → tag is cut → cross-repo bump PR updates `VERSION` here →
   `build.yaml` fires.
4. Existing apt installations upgrade cleanly: `1.32.13-lts.3` →
   `1.32.14-lts.0`.
