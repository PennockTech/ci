#!/bin/sh -eu

# These should be supplied by Docker
: "${SHARED_GO_AREA:?}" # /opt/gotools
: "${GOLANG_VERSION:?}" "${GOLANG_SRC_SHASUM:?}"

# shellcheck source=tools/lib.sh disable=SC2034
. "$(dirname "$0")/lib.sh" "$0" "$@"
startdir=/tmp
cd "$startdir"

user_bin_go() {
  info "go $*"
  (
    cat <<EOGOGET
export GOPATH='$SHARED_GO_AREA'
export PATH='${SHARED_GO_AREA}/bin:/usr/local/go/bin${PATH:+:}${PATH:-}'
export HOME='$SHARED_GO_AREA'
EOGOGET
    if [ -n "${CGO_ENABLED:-}" ]; then
      echo "export CGO_ENABLED='${CGO_ENABLED:?}'"
    fi
    printf '"%s"' "$GO_CMD"
    for x; do printf " '%s'" "$(printf '%s' "$x" | sed "s/'/'\"'\"'/")"; done
    printf '\n'
  ) | su -s /bin/sh bin
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

(
  cd /usr/local/go/pkg
  # reclaim 177 MiB:
  run rm -rf bootstrap/ obj
)
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

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~8< Dep >8~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

cd /tmp
mkdir release
Relative=release/dep-linux-amd64
download_to_tmp "https://github.com/golang/dep/releases/download/v${DEP_VERSION}/dep-linux-amd64" "$Relative"
download_to_tmp "https://github.com/golang/dep/releases/download/v${DEP_VERSION}/dep-linux-amd64.sha256" cksum.dep
# Note: dep v0.5.0 embeds absolute paths within Travis in their published checksum file.
# Insanity.
if grep -q -s "/$Relative" cksum.dep; then
  info Repairing dep checksum file
  mv -v cksum.dep cksum.dep.gross
  sed -n "s, /.*/${Relative}, ${Relative},p" <cksum.dep.gross >cksum.dep
  rm -v cksum.dep.gross
fi
sha256sum -c cksum.dep
chmod 0755 "./$Relative"
mv -v "./$Relative" /usr/local/bin/dep
rmdir release
rm -v cksum.dep
dep version

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~8< Go Packages >8~~~~~~~~~~~~~~~~~~~~~~~~~~~~

user_bin_go get github.com/jstemmer/go-junit-report
user_bin_go get \
  golang.org/x/crypto/... \
  golang.org/x/image/... \
  golang.org/x/net/... \
  golang.org/x/text/... \
  golang.org/x/sys/...
user_bin_go get github.com/pkg/errors github.com/lib/pq
# make a binary which might be copied into a final image
user_bin_go get -d github.com/tianon/gosu
CGO_ENABLED=0 user_bin_go install -ldflags "-d -s -w" github.com/tianon/gosu

# We also want ~/go to pre-exist, so that if Docker runs as root and populates
# a src/ path, it doesn't block dep from creating ~/go/pkg/dep/sources; it
# can still block the runtime user from downloading other sources though.
# Should probably "ADD --chown" the sources, but --chown doesn't interpolate
# (at least as of Docker 18.04) so that's harder to ensure.  This at least
# should make things a little easier.
mkdir -pv "$HOME/go/src" "$HOME/go/pkg" "$HOME/go/bin"

rm -rf "$SHARED_GO_AREA/.cache"
