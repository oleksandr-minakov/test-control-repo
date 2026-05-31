# Versioning — k8s-core on bundle `k8s-1.32`

Per §5, there is **one canonical record** rendered into each transport's
native ordering. Pin consumers by **digest** (images) or by the exact
`~lts<n>` revision (debs).

## Canonical record

```
upstream = 1.32.13
lts      = 1            # incremented on every LTS rebuild
bundle   = k8s-1.32
```

Stored authoritatively in `streams/k8s-1.32/<component>-1.32.yaml`.

## Per-transport rendering

| Transport | Renderer                                  | Result for the first build           |
|-----------|-------------------------------------------|--------------------------------------|
| OCI image | `scripts/render-oci-tags.sh v1.32.13 1`   | tag `1.32.13` (canonical, mutable) + tag `1.32.13-lts1` (human, stable) + immutable digest |
| Deb       | `scripts/render-deb-version.sh v1.32.13 1`| `1.32.13-1~lts1`                   |
| OCI labels (set in the build) | `_reusable-build-image.yml` | `net.lts.{component, upstream-tag, build, bundle, fork-branch}` |

apt ordering (verified with `dpkg --compare-versions`):

```
1.32.13-1            <  1.32.13-1~lts1     <  1.32.13-1~lts2     <  1.32.13-2
```

The `~lts<n>` form is **monotonically increasing** and never reserves a
future upstream version number. Bumping `lts` in the canonical record bumps
both `oci_human` and `deb_version` in lockstep.

## Things explicitly NOT used

- SemVer pre-release (`1.32.13-lts.1`) — sorts **below** the release and
  excluded from SemVer range matching.
- `+build` metadata — ignored for precedence, illegal in OCI tags.

## Bundle release tag

`k8s-1.32-lts.YYYY.MM` (+ `.hotfix.N` for KEV fast-track). Set by the
`bundle-release.yml` workflow input.

## When upstream releases v1.32.14

1. Open a PR that bumps `streams/k8s-1.32/*` `upstream.tag` to `v1.32.14` and
   resets `lts_build` to `1` on each stream.
2. Re-run each `component-*.yml` caller.
3. Existing apt installations upgrade cleanly:
   `1.32.13-1~lts3` → `1.32.14-1~lts1`.
