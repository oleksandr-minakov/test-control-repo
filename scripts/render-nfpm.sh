#!/usr/bin/env bash
# Render an nfpm config for a k8s-core deb (kubelet | kubectl).
# Consumed by .github/workflows/_reusable-build-deb.yml.
set -euo pipefail

usage() {
  cat <<EOF >&2
usage: render-nfpm.sh \\
  --component <kubelet|kubectl> \\
  --package <pkgname> \\
  --version <deb_version> \\
  --maintainer <"Name <email>"> \\
  --upstream-tag <vX.Y.Z> \\
  --bundle <k8s-1.32>
EOF
  exit 2
}

component= ; package= ; version= ; maintainer= ; upstream_tag= ; bundle=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --component)    component="$2"; shift 2;;
    --package)      package="$2"; shift 2;;
    --version)      version="$2"; shift 2;;
    --maintainer)   maintainer="$2"; shift 2;;
    --upstream-tag) upstream_tag="$2"; shift 2;;
    --bundle)       bundle="$2"; shift 2;;
    *) usage;;
  esac
done
[[ -z "$component$package$version$maintainer$upstream_tag$bundle" ]] && usage

case "$component" in
  kubelet)
    bin_src="src/_output/local/bin/linux/amd64/kubelet"
    bin_dst="/usr/bin/kubelet"
    systemd_unit_block=$(cat <<'UNIT'
contents:
  - src: packaging/kubelet.service
    dst: /lib/systemd/system/kubelet.service
  - src: packaging/10-kubeadm.conf
    dst: /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    type: config|noreplace
scripts:
  postinstall: packaging/kubelet.postinst
  prerm: packaging/kubelet.prerm
UNIT
)
    deps='[adduser, conntrack, iptables, iproute2, kubernetes-cni]'
    ;;
  kubectl)
    bin_src="src/_output/local/bin/linux/amd64/kubectl"
    bin_dst="/usr/bin/kubectl"
    systemd_unit_block=""
    deps='[]'
    ;;
  *) echo "unsupported component: $component" >&2; exit 1;;
esac

cat <<EOF
name: ${package}
arch: amd64
platform: linux
version: ${version}
section: admin
priority: optional
maintainer: ${maintainer}
description: |
  ${package} from LTS rebuild of kubernetes ${upstream_tag} (bundle ${bundle}).
  Reproducible, signed, and shipped from the LTS deb repository.
homepage: https://kubernetes.io
license: Apache-2.0
depends: ${deps}
contents:
  - src: ${bin_src}
    dst: ${bin_dst}
${systemd_unit_block}
EOF
