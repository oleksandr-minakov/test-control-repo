#!/usr/bin/env bash
# build.sh — Build a single Mirantis LTS component (image or deb).
#
# This is the SINGLE build entrypoint under the release-cascade model. The
# build workflow checks out the source fork at the resolved tag, then invokes
# this script once per matrix component. No reusable workflows, no per-
# component callers — just this script + .github/workflows/build.yaml.
#
# Flags:
#   --component <name>        kube-apiserver | kube-controller-manager | ...
#   --kind image|deb
#   --tag <vX.Y.Z-lts.N>      full tag with leading "v"
#   --registry-path <path>    ghcr.io/<org>/lts-k8s/<component> (image only)
#   --base-image <image>      required for kind=image; ignored for deb
#   --source-dir <dir>        defaults to "src"; pre-checked-out source fork

set -euo pipefail

component=""
kind=""
tag=""
registry_path=""
base_image=""
source_dir="src"

while [ $# -gt 0 ]; do
  case "$1" in
    --component)     component="$2";     shift 2 ;;
    --kind)          kind="$2";          shift 2 ;;
    --tag)           tag="$2";           shift 2 ;;
    --registry-path) registry_path="$2"; shift 2 ;;
    --base-image)    base_image="$2";    shift 2 ;;
    --source-dir)    source_dir="$2";    shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

[ -n "$component" ] || { echo "--component required" >&2; exit 2; }
[ -n "$kind" ]      || { echo "--kind required"      >&2; exit 2; }
[ -n "$tag" ]       || { echo "--tag required"       >&2; exit 2; }
[ -d "$source_dir" ] || { echo "source-dir '$source_dir' missing" >&2; exit 2; }

# Strip leading v for deb version field.
version="${tag#v}"
# Bundle is derived from the upstream minor (e.g. 1.32.13-lts.0 -> k8s-1.32).
minor="$(echo "$version" | cut -d. -f1-2)"
bundle="k8s-${minor}"

echo "==> build.sh"
echo "    component:     $component"
echo "    kind:          $kind"
echo "    tag:           $tag"
echo "    version:       $version"
echo "    bundle:        $bundle"
echo "    source-dir:    $source_dir"

case "$kind" in

  image)
    [ -n "$registry_path" ] || { echo "--registry-path required for kind=image" >&2; exit 2; }
    [ -n "$base_image" ]    || { echo "--base-image required for kind=image"    >&2; exit 2; }

    echo "==> [image] go build cmd/${component}"
    mkdir -p /tmp/bin
    (
      cd "$source_dir"
      GOFLAGS="-mod=vendor -trimpath -buildvcs=false" \
      GOPROXY=off \
      CGO_ENABLED=0 \
        go build -o "/tmp/bin/${component}" "./cmd/${component}"
    )

    workdir="$(mktemp -d)"
    cp "/tmp/bin/${component}" "${workdir}/${component}"

    cat > "${workdir}/Dockerfile.candidate" <<EOF
FROM ${base_image}
COPY ${component} /usr/local/bin/${component}
LABEL net.lts.component="${component}"
LABEL net.lts.tag="${tag}"
LABEL net.lts.bundle="${bundle}"
LABEL net.lts.source-repo="oleksandr-minakov/kubernetes"
ENTRYPOINT ["/usr/local/bin/${component}"]
EOF

    short_tag="${version}"
    candidate_tag="candidate-${GITHUB_RUN_ID:-local}"

    echo "==> [image] docker build → ${registry_path}:${short_tag}"
    docker build \
      -f "${workdir}/Dockerfile.candidate" \
      -t "${registry_path}:${short_tag}" \
      -t "${registry_path}:${candidate_tag}" \
      "${workdir}"

    echo "==> [image] docker push ${registry_path}:${short_tag}"
    docker push "${registry_path}:${short_tag}"
    echo "==> [image] docker push ${registry_path}:${candidate_tag}"
    docker push "${registry_path}:${candidate_tag}"

    digest="$(docker inspect --format='{{index .RepoDigests 0}}' "${registry_path}:${short_tag}" | sed "s|.*@|@|")"
    image_ref="${registry_path}${digest}"

    echo "==> [image] published: ${image_ref}"
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
      echo "image_ref=${image_ref}" >> "$GITHUB_OUTPUT"
    else
      echo "image_ref=${image_ref}"
    fi
    ;;

  deb)
    echo "==> [deb] go build cmd/${component}"
    mkdir -p dist
    (
      cd "$source_dir"
      GOFLAGS="-mod=vendor -trimpath -buildvcs=false" \
      GOPROXY=off \
      CGO_ENABLED=0 \
        go build -o "../dist/${component}" "./cmd/${component}"
    )

    if ! command -v nfpm >/dev/null 2>&1; then
      echo "==> [deb] installing nfpm from goreleaser apt repo"
      echo 'deb [trusted=yes] https://repo.goreleaser.com/apt/ /' | sudo tee /etc/apt/sources.list.d/goreleaser.list >/dev/null
      sudo apt-get update -qq
      sudo apt-get install -y nfpm
    fi

    if [ "$component" = "kubelet" ]; then
      depends='["adduser", "conntrack", "iptables", "iproute2", "kubernetes-cni"]'
    else
      depends='[]'
    fi

    nfpm_config="$(cat <<EOF
name: ${component}
arch: amd64
platform: linux
version: ${version}
section: admin
priority: optional
maintainer: "LTS Team <lts@example.com>"
description: |
  Mirantis LTS build of ${component} from kubernetes ${tag}.
homepage: https://github.com/oleksandr-minakov/test-control-repo
license: Apache-2.0
depends: ${depends}
contents:
  - src: dist/${component}
    dst: /usr/bin/${component}
    file_info:
      mode: 0755
EOF
)"

    echo "==> [deb] nfpm package"
    echo "$nfpm_config" | nfpm package -f /dev/stdin -p deb -t dist/

    deb_file="$(ls dist/${component}_*.deb | head -n1)"
    echo "==> [deb] published: ${deb_file}"
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
      echo "deb_path=${deb_file}" >> "$GITHUB_OUTPUT"
    else
      echo "deb_path=${deb_file}"
    fi
    ;;

  *)
    echo "unknown --kind: $kind (want image|deb)" >&2
    exit 2
    ;;
esac

echo "==> build.sh OK"
