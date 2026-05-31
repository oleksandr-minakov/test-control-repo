# Coverage matrix — per-release template

§9 requires every LTS release to state which upstream signal was reproduced
and which was skipped. This template is attached to each release's evidence
bundle and referenced from the customer advisory.

| Component                 | Bucket | Upstream targets run                                  | Skipped (and why)                                         |
|---------------------------|--------|-------------------------------------------------------|------------------------------------------------------------|
| kube-apiserver            | A      | `./cmd/kube-apiserver/...`, `./pkg/kubeapiserver/...`, `./test/integration/apiserver/...` | `test-e2e` (bucket B; deferred to Phase 2) |
| kube-controller-manager   | A      | `./cmd/kube-controller-manager/...`, `./pkg/controller/...` | `./test/integration/controllermanager/...` (bucket B; deferred) |
| kube-scheduler            | A      | `./cmd/kube-scheduler/...`, `./pkg/scheduler/...`     | —                                                          |
| kube-proxy                | B      | `./cmd/kube-proxy/...`, `./pkg/proxy/...`, kind ClusterIP smoke | `test-e2e --ginkgo.focus=Networking` (privileged runners required) |
| kubelet                   | B      | `./cmd/kubelet/...`, `./pkg/kubelet/...`, deb-install smoke    | `test-e2e-node` (bucket B; kernel/cgroup-sensitive)        |
| kubectl                   | A      | `./cmd/kubectl/...`, `./staging/src/k8s.io/kubectl/...`        | —                                                          |

For each release, regenerate from `streams/k8s-1.32/<component>-1.32.yaml`'s
`tests.skipped` field and the descriptor's `tests.upstream_targets`. The
matrix is part of the backport evidence, **not** marketing.
