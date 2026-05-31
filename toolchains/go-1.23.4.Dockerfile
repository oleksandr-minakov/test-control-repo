# Pinned Go toolchain image for hermetic k8s-core builds.
# Built + pushed by the toolchain workflow on a schedule (§6); referenced by
# digest from every component descriptor. Do not use floating tags.
#
# Build:
#   docker buildx build --platform=linux/amd64 \
#     -t ${REGISTRY}/lts/build/go-1.23.4 \
#     -f toolchains/go-1.23.4.Dockerfile toolchains/
#   docker push ...
#   # Capture the digest:
#   docker buildx imagetools inspect ${REGISTRY}/lts/build/go-1.23.4 \
#     --format '{{.Manifest.Digest}}'
#
# Refresh policy: rebuild quarterly OR on a Go security release. Pin a new
# digest into every k8s-core descriptor in the same PR — that PR is the audit
# trail that the toolchain moved.

# Pinned base by digest. ubuntu:22.04 chosen to match upstream k8s release-builder.
FROM ubuntu:22.04@sha256:TODO-PIN-UBUNTU-2204

ARG GO_VERSION=1.23.4
# TODO(maintainer): verify SHA against go.dev/dl/?mode=json on bump.
ARG GO_SHA256=TODO-PIN-GO-1.23.4-LINUX-AMD64-TARBALL

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      make \
      build-essential \
      rsync \
      jq \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/go.tgz "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
 && echo "${GO_SHA256}  /tmp/go.tgz" | sha256sum -c - \
 && tar -C /usr/local -xzf /tmp/go.tgz \
 && rm /tmp/go.tgz

ENV PATH=/usr/local/go/bin:/root/go/bin:$PATH \
    GOPATH=/root/go \
    GOFLAGS=-mod=readonly \
    GOSUMDB=off \
    CGO_ENABLED=0

# No GOPROXY default here — callers must inject MODULE_PROXY_URL so the
# image fails closed if the workflow forgot to set it.
RUN go version
