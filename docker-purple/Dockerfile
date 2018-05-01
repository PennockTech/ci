# PennockTech Dockerfile for pennocktech-ci-purple
#
# We work in two steps: as root, then as not-root.
# We use two stages, so that we can --target=rootstage to do other work.
#
# Multi-stage Dockerfile requires Docker 17.05 or higher.

# Note:
# ARG goes out of scope on the next FROM line, so any ARGs wanted have to be
# repeated in the context where you want them.  However, there's special
# treatment for any ARG which is declared before the very first FROM: the
# values become the defaults for later ARG of the same name, and these ARGs
# (and _only_ these ones) are available for use in the FROM lines themselves.
#
# Also, note that LABELs persist across inheritance boundaries, unless
# overridden.

ARG GOLANG_VERSION=1.10.2
ARG GOLANG_SRC_SHASUM=6264609c6b9cd8ed8e02ca84605d727ce1898d74efa79841660b2e3e985a98bd
ARG DEP_VERSION=0.4.1
ARG RUNTIME_USER=ci
ARG RUNTIME_GECOS='Continuous Integration'
ARG RUNTIME_UID=1001
ARG RUNTIME_GID=1001
#
# Neat/Evil hack: while in CI we use Docker-in-Docker, for local development
# it's nicer to bind-mount /var/run/docker.sock into the instance, so that
# you can run `docker ps` and see the outside docker.  The permissions and
# numeric ownership remain unchanged between the outside and inside.
# Using `docker-machine` (Boot2Docker version 18.02.0-ce), the socket is
# 0660 root:docker, where group docker is 100.  Assuming that we're derived
# from stretch (per default) group 100 is "users", which is _entirely_
# reasonable for the only runtime user to be a member of.  So go for it.
# Keep this as a comma-separated list of non-negative integers.
# In Alpine, gid of group "users" is again 100.
ARG RUNTIME_SUPGIDS=100

ARG SHARED_GO_AREA=/opt/gotools

# =========================8< STAGE: rootstage >8=========================

FROM alpine as rootstage
ARG GOLANG_VERSION
ARG GOLANG_SRC_SHASUM
ARG DEP_VERSION
ARG RUNTIME_USER
ARG RUNTIME_GECOS
ARG RUNTIME_UID
ARG RUNTIME_GID
ARG RUNTIME_SUPGIDS
ARG SHARED_GO_AREA

# Persisting this in ENV makes it available to RUN commands in the second stage:
ENV RUNTIME_USER=${RUNTIME_USER}

# This is not ideal; any change to the post-heavy script invalidates the cache
# of the heavy script.  For now, accepting that to move forward, but should
# find a way to fix this, and hopefully not via templating to auto-create
# Dockerfiles with filled in RUN sections.

COPY pkix/* /tmp/pkix/
COPY tools/* /tmp/tools/
COPY etc/* /tmp/etc/
RUN PT_VARIANT=purple VERBOSE=2 /tmp/tools/alpine-heavy.sh
RUN PT_VARIANT=purple VERBOSE=2 /tmp/tools/alpine-post-heavy.sh

env GOPATH=${SHARED_GO_AREA}
env PATH="${SHARED_GO_AREA}/bin:/usr/local/go/bin:${PATH}"

LABEL maintainer="noc+docker+ci@pennock-tech.com"
LABEL com.pennock-tech.name="Pennock Tech Continuous Integration (root-stage)"
LABEL com.pennock-tech.baseimage="alpine"
LABEL com.pennock-tech.versions.go="${GOLANG_VERSION}"
LABEL com.pennock-tech.versions.dep="${DEP_VERSION}"
LABEL com.pennock-tech.runtime.username="root"
LABEL com.pennock-tech.runtime.uid="0"
LABEL com.pennock-tech.runtime.gid="0"
LABEL com.pennock-tech.runtime.unprivileged="${RUNTIME_USER}"
LABEL com.pennock-tech.runtime.path="${PATH}"
LABEL com.pennock-tech.runtime.gopath="${GOPATH}"

# ======================8< STAGE: generated image >8======================

FROM rootstage

WORKDIR /home/${RUNTIME_USER}
# Deliberately no way back to root; use a rootstage if need root
USER ${RUNTIME_USER}

ENV GOPATH=/home/${RUNTIME_USER}/go:${GOPATH}
ENV PATH=/home/${RUNTIME_USER}/go/bin:${PATH}

# Reconsider how this should fit in, whether or not command can be overridden,
# when I delete scripts, etc.
# NB: TOFU requires GnuPG built with sqlite support, which is not the case
# for Alpine's package today.
RUN gpg </dev/null --batch --import etc/pgp-keys/pgp-philpennock-noattr.asc \
	&& echo "ACBB4324393ADE3515DA2DDA4D1E900E14C1CC04:6:" | gpg --import-ownertrust \
	&& gpg --check-trustdb
# && gpg --tofu-policy good ACBB4324393ADE3515DA2DDA4D1E900E14C1CC04

# Install any user-specific Go here

ARG RUNTIME_UID
ARG RUNTIME_GID
ARG RUNTIME_SUPGIDS
LABEL com.pennock-tech.name="Pennock Tech Continuous Integration"
LABEL com.pennock-tech.runtime.username="${RUNTIME_USER}"
LABEL com.pennock-tech.runtime.uid="${RUNTIME_UID}"
LABEL com.pennock-tech.runtime.gid="${RUNTIME_GID}"
LABEL com.pennock-tech.runtime.supgids="${RUNTIME_SUPGIDS}"
LABEL com.pennock-tech.runtime.path="${PATH}"
LABEL com.pennock-tech.runtime.gopath="${GOPATH}"
