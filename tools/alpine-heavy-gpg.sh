#!/bin/sh -eu

# These should be supplied by Docker
: "${RUNTIME_USER:?}" "${RUNTIME_UID:?}" "${RUNTIME_GID:?}"
: "${RUNTIME_GROUP:=$RUNTIME_USER}"
: "${RUNTIME_GECOS:=$RUNTIME_USER}"
: "${RUNTIME_SHELL:=/bin/sh}"

# This should find a proper home
: "${PT_GNUPG_TRUSTED_KEY:=0x4D1E900E14C1CC04}"

# shellcheck source=tools/lib.sh disable=SC2034
. "$(dirname "$0")/lib.sh" "$0" "$@"
startdir=/tmp
cd "$startdir"

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
