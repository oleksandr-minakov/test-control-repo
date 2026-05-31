# LTS Control Repo — `k8s-core` (bundle `k8s-1.32`)

Modular unified control repo for the LTS maintenance service. Currently
scoped to the six Kubernetes core components built from one upstream fork
([oleksandr-minakov/kubernetes](https://github.com/oleksandr-minakov/kubernetes)),
based on upstream **`v1.32.13`**:

| Component                 | Transport     | Test bucket | Registry / Artifact                                                            |
|---------------------------|---------------|-------------|--------------------------------------------------------------------------------|
| `kube-apiserver`          | OCI (ghcr.io) | A           | `ghcr.io/oleksandr-minakov/lts-k8s/kube-apiserver`                             |
| `kube-controller-manager` | OCI (ghcr.io) | A           | `ghcr.io/oleksandr-minakov/lts-k8s/kube-controller-manager`                    |
| `kube-scheduler`          | OCI (ghcr.io) | A           | `ghcr.io/oleksandr-minakov/lts-k8s/kube-scheduler`                             |
| `kube-proxy`              | OCI (ghcr.io) | B           | `ghcr.io/oleksandr-minakov/lts-k8s/kube-proxy`                                 |
| `kubelet`                 | deb           | B           | GHA artifact `deb-kubelet` (deb repository is out-of-scope for the test repo)  |
| `kubectl`                 | deb           | A           | GHA artifact `deb-kubectl`                                                     |

All six are built from one LTS branch in the source fork:
`lts/k8s-1.32/kubernetes-1.32`, cut from upstream `v1.32.13`.

## Pipeline (per component, all jobs in GHA-hosted ubuntu-latest)

```
load-descriptor   # parse components/<name>.yaml -> job outputs
   -> build       # hermetic-ish: golang:1.23.4-bookworm in --network=none container
   -> sbom        # Syft CycloneDX, uploaded as artifact
   -> scan        # Grype + (Aikido stub commented), merged findings JSON
   -> evidence    # patch-manifest + release-metadata.json from real outputs
   -> sign        # cosign keyless via OIDC -> Sigstore Fulcio/Rekor
   -> gate        # Conftest over policy/*.rego on release-metadata.json
   -> promote     # (image only) crane-retag canonical/human at GA digest
```

Candidate images are pushed to `:candidate-<run_id>`; canonical (`1.32.13`) and
human (`1.32.13-lts1`) tags are only repointed by the `promote` job on the
default branch, after the gate is green.

Debs are uploaded as GHA artifacts (`deb-kubelet`, `deb-kubectl`); the cosign
keyless `sign-blob` signature lands as a side artifact (`signing-<component>`).

## Layout

```
components/         Descriptors — one source of truth per component
streams/k8s-1.32/   Per-stream metadata
bundles/            Bundle manifest (the customer-facing release unit)
policy/             OPA/Conftest gates run on release-metadata.json
toolchains/         Pinned CLI versions + base Dockerfiles
scripts/            Version rendering, evidence assembly, advisory polling
.github/workflows/  6 reusable + 6 component callers + bundle + advisory monitor
docs/               Branching, versioning, runbooks, coverage matrix
patch-manifests/    Generated patch records + advisory cursor state
```

## Triggering

```bash
# Build one component:
gh workflow run component-kubectl.yml -f lts_build=1

# Or the bundle (collects current candidates, runs kind-based smoke):
gh workflow run bundle-release.yml -f tag=2026.06

# Advisory monitor (also runs hourly on cron):
gh workflow run advisory-monitor.yml
```

## What's stubbed in this test setup

The plan calls for a richer production stack; the test repo keeps the shape
of it but takes simpler defaults:

| Plan calls for             | Test repo uses                                  |
|----------------------------|-------------------------------------------------|
| Self-hosted frozen runners | `ubuntu-latest` (GHA-hosted)                    |
| Vault-issued cosign keys   | Cosign **keyless** via GHA OIDC -> Sigstore     |
| Aikido primary scanner     | Commented; Grype-only                           |
| Pinned toolchain by digest | `docker.io/library/golang:1.23.4-bookworm`      |
| Signed deb repository      | GHA `upload-artifact`                           |
| Module proxy (Athens)      | Not needed — k8s vendor tree is committed       |
| AI triage agent            | Stub script commented in advisory-monitor       |

All of these are commented and clearly scoped — uncomment when the
production setup is in place.

## See also

- [docs/branching.md](docs/branching.md) — branching model for the source fork
- [docs/versioning.md](docs/versioning.md) — OCI tag + deb revision rendering
- [docs/runbook-monthly-bundle.md](docs/runbook-monthly-bundle.md)
- [docs/runbook-kev-hotfix.md](docs/runbook-kev-hotfix.md)
- [docs/coverage-matrix-template.md](docs/coverage-matrix-template.md)
