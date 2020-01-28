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

ARG GOLANG_VERSION=1.13.7
ARG GOLANG_SRC_SHASUM=e4ad42cc5f5c19521fbbbde3680995f2546110b5c6aa2b48c3754ff7af9b41f4
ARG PT_VARIANT=purple
ARG RUNTIME_USER=ci
ARG RUNTIME_GECOS='Continuous Integration'
ARG RUNTIME_UID=1001
ARG RUNTIME_GID=1001
ARG RUNTIME_SHELL=/bin/sh
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
ARG PT_VARIANT
ARG RUNTIME_USER
ARG RUNTIME_GECOS
ARG RUNTIME_UID
ARG RUNTIME_GID
ARG RUNTIME_SHELL
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
RUN PT_VARIANT="${PT_VARIANT}" VERBOSE=2 /tmp/tools/alpine-heavy.sh
COPY tools/prepared-final-stage.sh /home/${RUNTIME_USER}/prepared-final-stage.sh

env GOPATH=${SHARED_GO_AREA}
env PATH="${SHARED_GO_AREA}/bin:/usr/local/go/bin:${PATH}"

LABEL maintainer="noc+docker+ci@pennock-tech.com"
LABEL com.pennock-tech.name="Pennock Tech Continuous Integration - $PT_VARIANT (root-stage)"
LABEL com.pennock-tech.baseimage="alpine"
LABEL com.pennock-tech.variant="${PT_VARIANT}"
LABEL com.pennock-tech.versions.go="${GOLANG_VERSION}"
LABEL com.pennock-tech.runtime.username="root"
LABEL com.pennock-tech.runtime.uid="0"
LABEL com.pennock-tech.runtime.gid="0"
LABEL com.pennock-tech.runtime.unprivileged="${RUNTIME_USER}"
LABEL com.pennock-tech.runtime.path="${PATH}"
LABEL com.pennock-tech.runtime.gopath="${GOPATH}"

# ======================8< STAGE: generated image >8======================

FROM rootstage

ARG PT_VARIANT
ARG RUNTIME_UID
ARG RUNTIME_GID
ARG RUNTIME_SHELL
ARG RUNTIME_SUPGIDS
# nb: RUNTIME_USER persisted in ENV from first stage

WORKDIR /home/${RUNTIME_USER}
# Deliberately no way back to root; use a rootstage if need root
USER ${RUNTIME_USER}

ENV HOME=/home/${RUNTIME_USER}
ENV GOPATH=${HOME}/go:${GOPATH}
ENV PATH=${HOME}/go/bin:${PATH}
ENV XDG_RUNTIME_DIR=/run/user/${RUNTIME_UID}

RUN ./prepared-final-stage.sh && rm -fv ./prepared-final-stage.sh

# Install any user-specific Go here

LABEL com.pennock-tech.name="Pennock Tech Continuous Integration - ${PT_VARIANT}"
LABEL com.pennock-tech.runtime.username="${RUNTIME_USER}"
LABEL com.pennock-tech.runtime.uid="${RUNTIME_UID}"
LABEL com.pennock-tech.runtime.gid="${RUNTIME_GID}"
LABEL com.pennock-tech.runtime.shell="${RUNTIME_SHELL}"
LABEL com.pennock-tech.runtime.supgids="${RUNTIME_SUPGIDS}"
LABEL com.pennock-tech.runtime.path="${PATH}"
LABEL com.pennock-tech.runtime.gopath="${GOPATH}"
