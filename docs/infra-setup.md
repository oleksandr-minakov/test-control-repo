# Infrastructure setup checklist

Every placeholder in the workflows/scripts maps to one item here. Until each
item is cleared the corresponding workflow either fails closed or runs as a
stub (this is intentional — see §6 and the README).

Owners: **Ops** for the platform plumbing; **Lead** for legal/key custody.

## GitHub org and repos

- [ ] **Org**: `oleksandr-minakov` private GitHub org with SSO and required-2FA.
- [ ] **Source fork**: push `source-fork-kubernetes/` (sibling tree) as
      `oleksandr-minakov/kubernetes`. Run `scripts/lts-branch-init.sh v1.32.13` inside
      the clone to cut `lts/k8s-1.32/kubernetes-1.32` from the upstream tag.
- [ ] **Control repo**: push this directory as `oleksandr-minakov/test-control-repo`. Enable
      branch protection on `main`: required reviews from CODEOWNERS, required
      status checks (every `component-*` gate + `bundle-gate`), restrict force
      push, disallow deletions.
- [ ] **Teams**: `lts-lead`, `lts-eng1`, `lts-eng2`, `lts-ops` mapped to GitHub
      teams so CODEOWNERS resolves.

## Self-hosted runners (`frozen-runner-v1`)

- [ ] **Runner pool**: amd64 Ubuntu 22.04 hosts joined to the org runner group
      `lts-bucket-a`, labelled `[self-hosted, linux, amd64, frozen-runner-v1]`.
- [ ] **Frozen image**: produce a node image from `toolchains/runner-os.md`
      and pin its disk image by digest. Rebuild quarterly.
- [ ] **Bucket B pool** (`frozen-runner-priv-vN`): larger CPU/RAM, privileged
      docker, nested-userns enabled — for `kube-proxy`/`kubelet` later.

## Toolchain images

- [ ] Build & push `${REGISTRY}/lts/build/go-1.23.4` from
      `toolchains/go-1.23.4.Dockerfile`. Pin Ubuntu + Go SHAs.
- [ ] Build & push `${REGISTRY}/lts/build/deb-build` from
      `toolchains/deb-build.Dockerfile`. Pin nfpm checksum.
- [ ] Capture the resulting digests and **replace every `TODO-PIN` in
      `components/*.yaml`** in a single PR. That PR is the audit trail.

## Base images

- [ ] `${REGISTRY}/lts/base/distroless-static` — rebuilt distroless used by
      apiserver/controller-manager/scheduler.
- [ ] `${REGISTRY}/lts/base/kube-proxy-base` — rebuilt minimal base with
      iptables/nft/ipset. kube-proxy cannot use distroless-static.
- [ ] Pin digests into `components/kube-*.yaml`.

## Vault (key custody)

- [ ] HashiCorp Vault deployed; online/offline split (§8).
- [ ] **Cosign signing key** issued via Vault transit; reference exported as
      GitHub Actions secret `COSIGN_KEY_REF`.
- [ ] **Deb repository signing key** (gpg, two-person custody); reference
      exported as `DEB_REPO_KEY_REF`.
- [ ] Quarterly rotation runbook (TODO).

## Registry

- [ ] Private OCI registry with referrers API support (Cosign needs it for
      attestations). If unavailable, fall back to side-stored attestations —
      see §10 "Registry lacks referrers/attestation support" mitigation.
- [ ] Secrets: `REGISTRY_HOST`, `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`.

## Module proxy

- [ ] Athens (or equivalent) configured as an in-org Go module proxy.
- [ ] Secret `MODULE_PROXY_URL` set to its address.

## Deb repository

- [ ] Aptly-backed deb repo hosted at `DEB_REPO_HOST`.
- [ ] Repository signing key per Vault item above.
- [ ] Suites: `k8s-1.32-lts`. Components: `main`.

## Aikido (primary scanner)

- [ ] Procurement closed; SBOM-upload endpoint and token known.
- [ ] Secret `AIKIDO_TOKEN` set; replace stub in `scripts/aikido-scan.sh`.

## AI triage endpoint

- [ ] Bounded triage agent deployed per `ai-agent-integration.md`. Secrets
      `AI_TRIAGE_ENDPOINT` and `AI_TRIAGE_TOKEN` set.
- [ ] Override-rate dashboard wired (90-day prove-it window).

## Deb-maintainer identity

- [ ] Replace `LTS Team <lts@example.com>` in `components/kubelet.yaml`
      and `components/kubectl.yaml` with the real publishing identity.

## Legal / redistribution (§8 GA blockers)

Not applicable to k8s-core directly (Apache-2.0, weak trademark posture), but
trademark clearance is recommended before GA — track in the Tier-1 onboarding
checklist.

---

When every box is ticked, the workflows run real instead of stub.
