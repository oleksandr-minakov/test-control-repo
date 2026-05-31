# Toolchain image for packaging k8s-core binaries (kubelet, kubectl) as .deb.
# Pure packaging only — the binary is produced in the Go toolchain image and
# bind-mounted in. Keeps the deb stage independent of Go upgrades.
FROM ubuntu:22.04@sha256:TODO-PIN-UBUNTU-2204

ARG NFPM_VERSION=2.41.1
# TODO(maintainer): pin checksum from goreleaser/nfpm release page.
ARG NFPM_SHA256=TODO-PIN-NFPM-CHECKSUM

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl jq lintian dpkg-dev gnupg \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/nfpm.tar.gz \
      "https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_Linux_x86_64.tar.gz" \
 && echo "${NFPM_SHA256}  /tmp/nfpm.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/nfpm.tar.gz -C /usr/local/bin nfpm \
 && rm /tmp/nfpm.tar.gz \
 && nfpm --version
