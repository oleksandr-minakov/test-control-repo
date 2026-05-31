# Frozen runner OS image

Per §6, the GHA self-hosted runner OS is referenced by digest and rebuilt
quarterly. The runner label set is `[self-hosted, linux, amd64, frozen-runner-v1]`.

When the image is rolled forward:
1. Build the new image from `runner-os.Dockerfile` (TODO: add when surge Ops
   stands up the runner fleet — see `docs/infra-setup.md#runners`).
2. Tag with the next label `frozen-runner-vN+1`.
3. Update every `runs-on:` line in `.github/workflows/component-*.yml`,
   `_reusable-*.yml`, and `bundle-release.yml` in one PR. That PR is the audit
   trail.
4. Run the quarterly cold-start rebuild test (`scripts/cold-start-rebuild.sh`,
   TODO) and diff the prior release's artifact bit-for-bit.

Runners need Docker (rootless preferred), nested user namespaces enabled for
`kind`, no nested KVM required (per §9 bucket A). Bucket-B work requires a
separate `frozen-runner-priv-vN` pool with larger CPU/RAM and privileged docker
— see `docs/infra-setup.md#runners-bucket-b`.
