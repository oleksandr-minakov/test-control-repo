# LTS Control Repo — `k8s-core` (bundle `k8s-1.32`)

Build repo for the LTS maintenance service (plan v3). Scoped to six Kubernetes
core components built from one upstream fork
([oleksandr-minakov/kubernetes](https://github.com/oleksandr-minakov/kubernetes)),
based on upstream **`v1.32.13`**.

| Component                 | Transport     | Test bucket | Registry / Artifact                                                              |
|---------------------------|---------------|-------------|----------------------------------------------------------------------------------|
| `kube-apiserver`          | OCI (ghcr.io) | A           | `ghcr.io/oleksandr-minakov/lts-k8s/kube-apiserver`                               |
| `kube-controller-manager` | OCI (ghcr.io) | A           | `ghcr.io/oleksandr-minakov/lts-k8s/kube-controller-manager`                      |
| `kube-scheduler`          | OCI (ghcr.io) | A           | `ghcr.io/oleksandr-minakov/lts-k8s/kube-scheduler`                               |
| `kube-proxy`              | OCI (ghcr.io) | B           | `ghcr.io/oleksandr-minakov/lts-k8s/kube-proxy`                                   |
| `kubelet`                 | deb           | B           | GHA artifact `deb-kubelet`                                                       |
| `kubectl`                 | deb           | A           | GHA artifact `deb-kubectl`                                                       |

## Two-layer test model (plan v3 §9)

**Tests live in the source fork; builds live here.** Each CVE backport is a PR
in [`oleksandr-minakov/kubernetes`](https://github.com/oleksandr-minakov/kubernetes),
where it runs upstream's own test workflows (kept as close to verbatim as
possible). This build repo only does hermetic build + artifact-level
validation. The release gate reads **both** layers.

```
   SOURCE FORK (oleksandr-minakov/kubernetes)
     PR on lts/k8s-1.32/kubernetes-1.32
       → .github/workflows/lts-tests.yml
          • unit (bucket A) — per matrix per component
          • build (compile-check all six)
          • [scheduled: bucket B/C/D where available]
       → human review (Tier-1 non-clean → two reviewers)
       → merge to lts/k8s-1.32/kubernetes-1.32

   BUILD REPO (this repo)
     component-<X>.yml triggered after merge
       → build       (setup-go, -mod=vendor, GOPROXY=off)
       → sbom        (Syft CycloneDX)
       → scan        (Grype; Aikido stub commented)
       → artifact-smoke   ← v3 §9 build-repo gate (image --version + label check / dpkg-deb -x + binary --version)
       → evidence    (fetch fork lts-tests check-runs → release-metadata.json)
       → sign        (cosign keyless via OIDC → Sigstore)
       → gate        (Conftest over policy/*.rego; reads BOTH source-tests and artifact-smoke)
       → promote     (image only: crane retag canonical/human at GA digest)
```

The gate is hard: `tests.source_repo.status == "passed"` is required for any
tier-1 release. If `lts-tests` on the fork hasn't run green at the source SHA
being built, the gate fails closed.

## Triggering

```bash
# Step 1 (on the fork): run lts-tests on the LTS branch tip so the build repo
# has a "passed" status to read.
gh workflow run lts-tests.yml --repo oleksandr-minakov/kubernetes --ref lts/k8s-1.32/kubernetes-1.32

# Step 2 (on this repo): build one component.
gh workflow run component-kubectl.yml -f lts_build=1

# Or the bundle (collects current candidates, runs kind smoke):
gh workflow run bundle-release.yml -f tag=2026.06

# Advisory monitor (also runs hourly on cron):
gh workflow run advisory-monitor.yml
```

## Layout

```
components/         Descriptors — one source of truth per component
streams/k8s-1.32/   Per-stream metadata
bundles/            Bundle manifest (the customer-facing release unit)
policy/             OPA/Conftest gates (now check fork-test status + artifact smoke)
toolchains/         Pinned CLI versions
scripts/            Version rendering, evidence assembly, fork-test fetch
.github/workflows/  Reusables + 6 component callers + bundle + advisory monitor
docs/               Branching, versioning, runbooks, coverage matrix
patch-manifests/    Generated patch records + advisory cursor state
```

## What's stubbed in this test setup

| Plan calls for             | Test repo uses                                  |
|----------------------------|-------------------------------------------------|
| Self-hosted frozen runners | `ubuntu-latest` (GHA-hosted)                    |
| Vault-issued cosign keys   | Cosign **keyless** via GHA OIDC → Sigstore      |
| Aikido primary scanner     | Commented; Grype-only                           |
| Pinned toolchain by digest | `actions/setup-go@v5` with version derived from descriptor |
| Signed deb repository      | GHA `upload-artifact`                           |
| Module proxy (Athens)      | Not needed — k8s vendor tree is committed       |
| AI triage agent            | Stub script commented in advisory-monitor       |
| Full bucket-A test set     | `./cmd/<x>/...` only (upstream's pkg/ + test/integration trimmed for free-runner time budget) |

## See also

- [docs/branching.md](docs/branching.md)
- [docs/versioning.md](docs/versioning.md)
- [docs/runbook-monthly-bundle.md](docs/runbook-monthly-bundle.md)
- [docs/runbook-kev-hotfix.md](docs/runbook-kev-hotfix.md)
- [docs/coverage-matrix-template.md](docs/coverage-matrix-template.md)
- Fork: [lts-tests.yml on the source fork](https://github.com/oleksandr-minakov/kubernetes/blob/lts/k8s-1.32/kubernetes-1.32/.github/workflows/lts-tests.yml)
