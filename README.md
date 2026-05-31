# LTS Control Repo — `k8s-core` (bundle `k8s-1.32`)

Build repo for the Mirantis LTS release cascade. Scoped to six Kubernetes
core components built from one upstream fork
([oleksandr-minakov/kubernetes](https://github.com/oleksandr-minakov/kubernetes)),
on `release-1.32`, currently at **`v1.32.13-lts.0`** (see `VERSION`).

| Component                 | Transport     | Registry / Artifact                                              |
|---------------------------|---------------|------------------------------------------------------------------|
| `kube-apiserver`          | OCI (ghcr.io) | `ghcr.io/oleksandr-minakov/lts-k8s/kube-apiserver`               |
| `kube-controller-manager` | OCI (ghcr.io) | `ghcr.io/oleksandr-minakov/lts-k8s/kube-controller-manager`      |
| `kube-scheduler`          | OCI (ghcr.io) | `ghcr.io/oleksandr-minakov/lts-k8s/kube-scheduler`               |
| `kube-proxy`              | OCI (ghcr.io) | `ghcr.io/oleksandr-minakov/lts-k8s/kube-proxy`                   |
| `kubelet`                 | deb           | GHA artifact `deb-kubelet`                                       |
| `kubectl`                 | deb           | GHA artifact `deb-kubectl`                                       |

## The cascade

The control-repo no longer pulls test status from the source fork at build
time. Test enforcement happens upstream of the build via branch protection;
by the time a tag exists, everything required has already been gated.

```
   SOURCE FORK (oleksandr-minakov/kubernetes, branch release-1.32)
     CVE/backport PR
       → .github/workflows/mirantis_release.yaml  (lts-tests: unit + compile)
       → required-check branch protection
       → merge into release-1.32
       → release-please
            • bumps source-fork/version.txt
            • updates source-fork/CHANGELOG.md
            • opens / merges a release PR
            • cuts tag  vX.Y.Z-lts.N  on release-1.32
       → release-please-action ALSO opens a cross-repo bump PR against
         oleksandr-minakov/test-control-repo updating /VERSION to the new tag.

   BUILD REPO (this repo)
     PR lands on a release-* branch updating VERSION
       → .github/workflows/build.yaml fires (push: paths=[VERSION])
       → resolve VERSION → tag
       → matrix builds 6 components in parallel via ./build.sh:
            kube-apiserver, kube-controller-manager, kube-scheduler,
            kube-proxy           (kind=image)  → ghcr.io publish
            kubelet, kubectl     (kind=deb)    → GHA artifact
       → per artifact: syft SBOM, grype scan, cosign keyless sign,
                        + cosign attest CycloneDX (images only)
     Daily scan.yaml re-pulls the 4 published images and re-runs syft+grype.
```

`build.sh` is the single build entrypoint — POSIX bash, self-contained nfpm
rendering, no reusable workflows, no per-component callers.

## How to test the cascade

Bootstrap (you only need this once per cluster of test repos):

1. In the source fork: ensure `.github/workflows/mirantis_release.yaml`,
   `version.txt`, and `CHANGELOG.md` exist on `release-1.32`. Branch
   protection on `release-1.32` should require the `lts-tests` checks.
2. In the build repo: ensure `VERSION` exists on a `release-1.32` branch
   with content like `v1.32.13-lts.0`.
3. Configure release-please-action in the source fork with a target of this
   build repo and `path: VERSION`.

Run an end-to-end pass:

```bash
# In the source fork, open a no-op PR to release-1.32, get lts-tests green,
# merge. release-please opens its release PR; merge that too. A tag will
# appear, and a cross-repo bump PR will appear here.
#
# In this repo, merge the bump PR → build.yaml runs.
#
# Force-run without waiting for the cascade:
gh workflow run build.yaml --ref release-1.32 -F source_ref=v1.32.13-lts.0

# Daily image rescan:
gh workflow run scan.yaml --ref release-1.32
```

## Layout

```
VERSION              Canonical tag the cascade landed (e.g. v1.32.13-lts.0)
build.sh             Single build entrypoint — image OR deb, per component
components/          Descriptors — one source of truth per component
streams/k8s-1.32/    Per-stream metadata
bundles/             Bundle manifest (the customer-facing release unit)
policy/              OPA/Conftest gates (artifact-level only; cascade
                     handles test gating upstream)
toolchains/          Pinned CLI versions
scripts/             Version rendering, evidence assembly
.github/workflows/   build.yaml + scan.yaml — that's it
docs/                Branching, versioning, runbooks, coverage matrix
patch-manifests/     Generated patch records + advisory cursor state
```

## What's stubbed in this test setup

| Plan calls for             | Test repo uses                                  |
|----------------------------|-------------------------------------------------|
| Self-hosted frozen runners | `ubuntu-latest` (GHA-hosted)                    |
| Vault-issued cosign keys   | Cosign **keyless** via GHA OIDC → Sigstore      |
| Aikido primary scanner     | Commented; Grype-only                           |
| Pinned toolchain by digest | `actions/setup-go@v5` with version from src/.go-version |
| Signed deb repository      | GHA `upload-artifact`                           |
| Module proxy (Athens)      | Not needed — k8s vendor tree is committed       |

## See also

- [docs/branching.md](docs/branching.md)
- [docs/versioning.md](docs/versioning.md)
- [docs/runbook-monthly-bundle.md](docs/runbook-monthly-bundle.md)
- [docs/runbook-kev-hotfix.md](docs/runbook-kev-hotfix.md)
- Source fork:
  [oleksandr-minakov/kubernetes @ release-1.32](https://github.com/oleksandr-minakov/kubernetes/tree/release-1.32)
