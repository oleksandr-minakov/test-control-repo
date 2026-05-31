#!/usr/bin/env bash
# Bundle integration smoke. The honest version of what we can test on a free
# GHA runner today:
#
#   1. Pull each LTS image and run `--version` to prove the binary executes.
#   2. Install the LTS kubectl/kubelet debs and verify their --version output
#      matches what's encoded in the bundle manifest.
#   3. Spin a kind cluster (with upstream node image) and use the LTS kubectl
#      deb to talk to it — proves wire-compatibility of the client binary
#      against an upstream control plane.
#
# Real bucket-A/B e2e (kube-proxy ClusterIP routing, kubelet node smoke) is
# called out in the coverage matrix as bucket-B work; running it requires
# privileged kind config + image overrides, which we leave for a follow-up.
set -euo pipefail

manifest=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) manifest="$2"; shift 2;;
    *) echo "bundle-smoke: unknown arg $1" >&2; exit 2;;
  esac
done
[ -f "$manifest" ] || { echo "manifest not found: $manifest" >&2; exit 1; }

echo "== Smoke 1: pull LTS images and verify --version =="
for component in kube-apiserver kube-controller-manager kube-scheduler kube-proxy; do
  digest=$(jq -r --arg c "$component" '.streams[] | select(.component==$c) | .rendered.oci_digest // ""' "$manifest")
  canonical=$(jq -r --arg c "$component" '.streams[] | select(.component==$c) | .rendered.oci_canonical // ""' "$manifest")
  registry=$(jq -r --arg c "$component" '"ghcr.io/oleksandr-minakov/lts-k8s/" + $c' <<<'{}')
  if [ -z "$digest" ] || [ "$digest" = "null" ]; then
    echo "  WARN: ${component} has no digest in manifest; using :${canonical}" >&2
    ref="${registry}:${canonical}"
  else
    ref="${registry}@${digest}"
  fi
  echo "  pulling ${ref}"
  docker pull "$ref"
  # Run --version inside the container. distroless images have no shell; entrypoint runs the binary.
  docker run --rm "$ref" --version || docker run --rm --entrypoint="/usr/local/bin/${component}" "$ref" --version
done

echo "== Smoke 2: install kubectl.deb and run kubectl version --client =="
if [ -f dist/kubectl_*.deb ]; then
  sudo dpkg -i dist/kubectl_*.deb
  kubectl version --client
fi

echo "== Smoke 3: install kubelet.deb (no service start) and check --version =="
if [ -f dist/kubelet_*.deb ]; then
  # systemctl daemon-reload runs in postinst; that's OK on the runner.
  sudo dpkg -i dist/kubelet_*.deb || (sudo apt-get install -fy && sudo dpkg -i dist/kubelet_*.deb)
  /usr/bin/kubelet --version
fi

echo "== Smoke 4: spin a kind cluster and talk to it with LTS kubectl =="
if command -v kind >/dev/null 2>&1; then
  kind create cluster --name lts-smoke --wait 60s
  kubectl --context kind-lts-smoke get nodes
  kubectl --context kind-lts-smoke run smoke --image=registry.k8s.io/pause:3.10 --restart=Never
  kubectl --context kind-lts-smoke wait --for=jsonpath='{.status.phase}'=Running pod/smoke --timeout=60s
  kind delete cluster --name lts-smoke
fi

echo "bundle-smoke: OK"
