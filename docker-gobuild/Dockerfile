# PennockTech Dockerfile for pennocktech-ci-gobuild
#
# We provide pennocktech/ci:gobuild-${VERSION} and a -root suffix variant.

ARG GOLANG_VERSION=1.15.3
ARG UPSTREAM_IMAGE=golang:${GOLANG_VERSION}-alpine
ARG REPO_STATE=UNKNOWN

ARG PT_VARIANT=gobuild

# These all match the purple set.
ARG RUNTIME_USER=builder
ARG RUNTIME_GECOS='Go Build'
ARG RUNTIME_UID=1001
ARG RUNTIME_GID=1001
ARG RUNTIME_SHELL=/bin/sh
ARG RUNTIME_SUPGIDS=100

# =========================8< STAGE: rootstage >8=========================

FROM ${UPSTREAM_IMAGE} as rootstage
ARG UPSTREAM_IMAGE
ARG GOLANG_VERSION
ARG PT_VARIANT
ARG REPO_STATE

# bash: for build scripts which use arrays
# git: for go get
# docker-cli: to build docker images with docker-in-docker
RUN apk update && apk upgrade --no-cache && \
	apk add --no-cache bash git docker-cli

LABEL maintainer="noc+docker+ci@pennock-tech.com"
LABEL com.pennock-tech.name="Pennock Tech Continuous Integration - ${PT_VARIANT} (root-stage)"
LABEL com.pennock-tech.baseimage="${UPSTREAM_IMAGE}"
LABEL com.pennock-tech.variant="${PT_VARIANT}"
LABEL com.pennock-tech.versions.go="${GOLANG_VERSION}"
LABEL com.pennock-tech.runtime.username="root"
LABEL com.pennock-tech.runtime.uid="0"
LABEL com.pennock-tech.runtime.gid="0"
LABEL com.pennock-tech.buildrepo.url="https://github.com/PennockTech/ci"
LABEL com.pennock-tech.buildrepo.state="${REPO_STATE}"

# =======================8< STAGE: unprivileged >8========================

FROM rootstage

ARG PT_VARIANT
ARG RUNTIME_UID
ARG RUNTIME_GID
ARG RUNTIME_SHELL
ARG RUNTIME_SUPGIDS
ARG RUNTIME_USER
ENV RUNTIME_USER=${RUNTIME_USER}

# Workdir is inherited as /go
RUN addgroup -g "$RUNTIME_GID" "$RUNTIME_USER" && \
	adduser -h "/home/$RUNTIME_USER" -s "$RUNTIME_SHELL" -g "$RUNTIME_GECOS" -G "$RUNTIME_USER" -D -u "$RUNTIME_UID" "$RUNTIME_USER" && \
	mkdir -pv /run/user/${RUNTIME_UID} && \
	chown -R ${RUNTIME_UID}:${RUNTIME_GID} /go /run/user/${RUNTIME_UID}

USER ${RUNTIME_USER}

ENV XDG_RUNTIME_DIR=/run/user/${RUNTIME_UID}

LABEL com.pennock-tech.name="Pennock Tech Continuous Integration - ${PT_VARIANT}"
LABEL com.pennock-tech.runtime.username="${RUNTIME_USER}"
LABEL com.pennock-tech.runtime.uid="${RUNTIME_UID}"
LABEL com.pennock-tech.runtime.gid="${RUNTIME_GID}"
LABEL com.pennock-tech.runtime.shell="${RUNTIME_SHELL}"
LABEL com.pennock-tech.runtime.supgids="${RUNTIME_SUPGIDS}"
