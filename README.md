# LTS Control Repo — `k8s-core` (bundle `k8s-1.32`)

This is the **modular unified control repo** (§4) for the LTS service. It
currently scopes the six Kubernetes core components built from one upstream
repo (`kubernetes/kubernetes`), based on upstream **`v1.32.13`**:

| Component                 | Transport | Bucket | Owner | Descriptor                                      |
|---------------------------|-----------|--------|-------|-------------------------------------------------|
| `kube-apiserver`          | OCI       | A      | eng-2 | [components/kube-apiserver.yaml](components/kube-apiserver.yaml) |
| `kube-controller-manager` | OCI       | A      | eng-2 | [components/kube-controller-manager.yaml](components/kube-controller-manager.yaml) |
| `kube-scheduler`          | OCI       | A      | eng-2 | [components/kube-scheduler.yaml](components/kube-scheduler.yaml) |
| `kube-proxy`              | OCI       | B      | eng-1 | [components/kube-proxy.yaml](components/kube-proxy.yaml) |
| `kubelet`                 | deb       | B      | eng-1 | [components/kubelet.yaml](components/kubelet.yaml) |
| `kubectl`                 | deb       | A      | eng-2 | [components/kubectl.yaml](components/kubectl.yaml) |

All six are built from one LTS branch in the private fork:
`lts/k8s-1.32/kubernetes-1.32` of `oleksandr-minakov/kubernetes`.

## Layout

```
components/         Descriptors — one source of truth per component (§6)
streams/k8s-1.32/   Per-stream metadata (lifecycle, rendered versions)
bundles/            Bundle manifests (the customer-facing release unit)
policy/             OPA/Conftest gates run on release metadata (§6)
toolchains/         Pinned Go + deb-build images, runner OS, CLI pins
scripts/            Version rendering, evidence assembly, advisory polling
.github/workflows/  Reusable workflows + one caller per component
docs/               Runbooks, branching, versioning, infra-setup checklist
patch-manifests/    Generated patch records (do not hand-edit)
```

## How a release happens (Appendix A, in code)

1. Hourly, `.github/workflows/advisory-monitor.yml` polls each descriptor's
   `advisory_sources` and opens an Issue per CVE×component.
2. AI triage proposes VEX status + cherry-pick feasibility as an Issue
   comment. **Humans confirm; no autonomous merges** (§8).
3. Backport PR opened in the source fork; merged into
   `lts/k8s-1.32/kubernetes-1.32`.
4. Component caller workflow runs:
   build → SBOM → scan → assemble evidence → sign → policy gate.
5. Monthly, `bundle-release.yml` collects candidate digests into a bundle
   manifest, runs integration smoke, runs the bundle policy gate, and opens
   a GA promotion PR (Lead approval required per `CODEOWNERS`).

## What is NOT done yet (intentional)

This repo is the skeleton produced from the plan in
`lts_maintenance_plan_v2_2.md`. The following items are tracked in
[docs/infra-setup.md](docs/infra-setup.md):

- Toolchain image digests (Go 1.23.4 + deb-build) — `TODO-PIN`.
- Base image digests (distroless-static, kube-proxy-base) — `TODO-PIN`.
- Vault setup, signing keys, deb repo key — secrets are placeholders.
- Aikido endpoint — `aikido-scan.sh` runs as stub until procurement closes.
- Self-hosted runner pool (`frozen-runner-v1`) — see `toolchains/runner-os.md`.

These are out-of-band; the workflows fail closed when they're missing.

## Authoritative references

- [`lts_maintenance_plan_v2_2.md`](../../lts_maintenance_plan_v2_2.md) — the
  plan this repo implements.
- `constraints.md` (project knowledge) — wins on any disagreement.
