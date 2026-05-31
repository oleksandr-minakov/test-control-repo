# patch-manifests/

Generated artifacts. **Do not hand-edit.**

These are produced by `scripts/render-patch-manifest.sh` during each
component release, from:

1. `git log lts/k8s-1.32/kubernetes-1.32 --grep '^LTS-Patch:'` for commit
   trailers.
2. `gh issue list --label cve --json ...` for ticket state and VEX
   justification.

The `state/` subdirectory holds the advisory-monitor cursor file — also
auto-managed.

See §4 ("Patch queue — git + issues as canonical, rendered to YAML").
