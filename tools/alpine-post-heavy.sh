#!/bin/sh -eu

# These should be supplied by Docker
: "${PT_VARIANT:?}" # purple
: "${RUNTIME_USER:?}" "${RUNTIME_UID:?}" "${RUNTIME_GID:?}"
: "${SHARED_GO_AREA:?}" # /opt/gotools
: "${GOLANG_VERSION:?}" "${GOLANG_SRC_SHASUM:?}"
: "${RUNTIME_GROUP:=$RUNTIME_USER}"
: "${RUNTIME_GECOS:=$RUNTIME_USER}"
: "${RUNTIME_SHELL:=/bin/sh}"

# This should find a proper home
: "${PT_GNUPG_TRUSTED_KEY:=0x4D1E900E14C1CC04}"

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

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~8< Dep >8~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

cd /tmp
mkdir release
download_to_tmp "https://github.com/golang/dep/releases/download/v${DEP_VERSION}/dep-linux-amd64" release/dep-linux-amd64
download_to_tmp "https://github.com/golang/dep/releases/download/v${DEP_VERSION}/dep-linux-amd64.sha256" cksum.dep
sha256sum -c cksum.dep
chmod 0755 ./release/dep-linux-amd64
mv -v ./release/dep-linux-amd64 /usr/local/bin/dep
rmdir release
dep version

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~8< Python >8~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

pip install --upgrade pip setuptools
pip3 install --upgrade pip setuptools
pip3 install -r "etc/py-requirements-${PT_VARIANT:?}.txt"

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
# a src/ path, that it doesn't block dep from creating ~/go/pkg/dep/sources; it
# can still block the runtime user from downloading other sources though.
# Should probably "ADD --chown" the sources, but --chown doesn't interpolate
# (at least as of Docker 18.04) so that's harder to ensure.  This at least
# should make things a little easier.
mkdir -pv "$HOME/go/src" "$HOME/go/pkg" "$HOME/go/bin"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~8< Others >8~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Skipping "heroku": requires node runtime
# Consider:
#  * docker
#  * kubernetes

# ~~~~~~~~~~~~~~~~~~~~~~8< Trust Anchors: OpenPGP >8~~~~~~~~~~~~~~~~~~~~~~

keydir="/home/${RUNTIME_USER}/etc/pgp-keys"
pgpdir="/home/${RUNTIME_USER}/.gnupg"
mkdir -pv "$keydir"
mkdir -pv "$pgpdir/CA"

cd /tmp
cp -v etc/pgp*.asc "$keydir/./"
cp -v etc/hkp-*.pem etc/sks-*.pem "$pgpdir/CA/./"
chown -R "${RUNTIME_USER}:${RUNTIME_GROUP}" "$keydir"

cat >"$pgpdir/gpg.conf" <<EOGPGCONF
no-greeting
no-secmem-warning
keyid-format 0xlong
display-charset utf-8
no-comments
no-version
# TOFU requires GnuPG built with sqlite to even parse the options.
#trust-model tofu+pgp
#tofu-default-policy unknown

trusted-key ${PT_GNUPG_TRUSTED_KEY}
keyserver hkp://ha.pool.sks-keyservers.net
#keyserver hkp://subset.pool.sks-keyservers.net
auto-key-locate local,dane,wkd
EOGPGCONF

cat >"$pgpdir/dirmngr.conf" <<EODIRMNGR
#log-file ${pgpdir}/log.dirmngr
#verbose
#debug-all
#gnutls-debug 9
allow-ocsp
hkp-cacert ${pgpdir}/CA/hkp-cacerts.pem
allow-version-check
EODIRMNGR

chmod -R go-rwx "$pgpdir"
chown -R "${RUNTIME_USER}:${RUNTIME_GROUP}" "/home/${RUNTIME_USER}"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~8< User config >8~~~~~~~~~~~~~~~~~~~~~~~~~~~~

for F in /tmp/etc/dot.*; do
  install -o "${RUNTIME_USER}" -m 0600 "$F" "/home/${RUNTIME_USER}/${F##*/dot}"
done

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~8< Cleanup >8~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

rm -rf "$SHARED_GO_AREA/.cache"

cd /tmp
rm -rf pkix tools etc
