#!/bin/sh -eu

# These should be supplied by Docker
: "${PT_VARIANT:?}" # purple
: "${RUNTIME_USER:?}" "${RUNTIME_UID:?}" "${RUNTIME_GID:?}"
: "${SHARED_GO_AREA:?}" # /opt/gotools
: "${GOLANG_VERSION:?}" "${GOLANG_SRC_SHASUM:?}"
: "${RUNTIME_GROUP:=$RUNTIME_USER}"
: "${RUNTIME_GECOS:=$RUNTIME_USER}"
: "${RUNTIME_SHELL:=/bin/sh}"

# shellcheck source=tools/lib.sh disable=SC2034
. "$(dirname "$0")/lib.sh" "$0" "$@"
startdir=/tmp
cd "$startdir"

run apk update
run apk upgrade

# coreutils includes base64, sha256sum, etc (and normally also built into busybox)
# need gcc, libffi etc for python packages
run apk add \
  musl-dev \
  openssl gnutls-utils gnupg \
  git mercurial \
  coreutils tar \
  binutils chrpath file \
  curl wget rsync socat \
  pcre-tools ncurses \
  clang gcc make linux-headers libffi libffi-dev \
  zip xz \
  bash zsh vim groff less \
  python3 python3-dev py-pip mailcap \
  unbound unbound-libs unbound-dev \
  github-cli bind-tools ldns-tools drill \
  go
# that go will be 1.9.4 but will let us bootstrap a current Go

# Installing Docker from upstream currently gets 18.02;
# Alpine v3.7 has 17.12.1-r0 while edge (future v3.8) has 18.02.0-r0

run addgroup -g "$RUNTIME_GID" "$RUNTIME_GROUP"
run adduser -h "/home/$RUNTIME_USER" -s "$RUNTIME_SHELL" \
  -g "$RUNTIME_GECOS" -G "$RUNTIME_GROUP" -D \
  -u "$RUNTIME_UID" "$RUNTIME_USER"

for gid in $RUNTIME_SUPGIDS; do
  # Alpine won't take a gid
  gname="$(awk -F : '$3 == '"$gid"' { print $1 }' </etc/group)"
  run adduser "$RUNTIME_USER" "$gname"
done

if [ -d pkix ]; then
  run mkdir -pv /usr/local/share/ca-certificates
  run cp -v pkix/*.crt /usr/local/share/ca-certificates/./
  run update-ca-certificates
fi

# Per docker-library/docker, persuade Go code to play with Docker hacks
[ -e /etc/nsswitch.conf ] || echo 'hosts: files dns' >/etc/nsswitch.conf

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~8< Go >8~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

user_bin_go() {
  su -s /bin/sh bin <<EOGOGET
export GOPATH='$SHARED_GO_AREA'
export PATH='${SHARED_GO_AREA}/bin:/usr/local/go/bin${PATH:+:}${PATH:-}'
export HOME='$SHARED_GO_AREA'
"$GO_CMD" $@
EOGOGET
}

fn="go${GOLANG_VERSION}.src.tar.gz"
download_to_tmp_sha256 "https://dl.google.com/go/${fn}" "$fn" "${GOLANG_SRC_SHASUM:?}"
run tar -C /usr/local -zxBpf "/tmp/$fn"
rm -f "/tmp/$fn"

cd /usr/local/go/src
GOROOT_BOOTSTRAP="$(go env GOROOT)" \
GOOS="$(go env GOOS)" \
GOARCH="$(go env GOARCH)" \
GOHOSTOS="$(go env GOHOSTOS)" \
GOHOSTARCH="$(go env GOHOSTARCH)" \
  ./make.bash
run apk del go

cd /usr/local/go/pkg
# reclaim 177 MiB:
run rm -rf bootstrap/ obj
cd ..
rm -rf doc # another 4.3MiB

cd "$startdir"

# The run-time user should have a GOPATH of $HOME/go:/opt/gotools and use the
# first for all their stuff, but be able to pull from later locations, and
# have that area's bin in $PATH
run mkdir -pv "${SHARED_GO_AREA}/bin"
run chown -R bin "${SHARED_GO_AREA}"
export GOPATH="$SHARED_GO_AREA"

user_bin_go version
user_bin_go get golang.org/x/tools/cmd/...

rm -v /var/cache/apk/*
