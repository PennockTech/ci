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

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~8< Packages >8~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

run apk update
run apk upgrade --no-cache

# coreutils includes base64, sha256sum, etc (and normally also built into busybox)
# need gcc, libffi etc for python packages
#
# Any go will be dated but will let us bootstrap a current Go.
# Eg, when first wrote this, this installed 1.9.4 which let us install 1.10
# ourselves.
#
# Repetition in these is okay.
readonly CriticalPackages="openssl curl jq git openssh-client"
readonly GoPackages="go musl-dev bash make" # bash/make for building local Go
readonly NicerDebugPackages="zsh tar socat pcre-tools chrpath less file strace binutils"
readonly PythonPackages="gcc make linux-headers libffi libffi-dev python3 python3-dev py-pip"
readonly DNSPackages="unbound unbound-libs unbound-dev bind-tools ldns-tools drill"
readonly CryptoPackages="openssl gnutls-utils gnupg"
readonly RepoPackages="git mercurial github-cli"
readonly KitchenSinkPackages="
  $CriticalPackages
  $GoPackages
  $NicerDebugPackages
  $PythonPackages
  $DNSPackages
  $CryptoPackages
  $RepoPackages
  musl-dev
  openssl-dev
  coreutils
  wget rsync
  ncurses
  clang
  zip xz
  bash zsh vim groff man
  mailcap
  docker
"

packages="$CriticalPackages"

case "${PT_VARIANT:-heavy}" in
pastel) ;;
heavy | purple)
  packages="$KitchenSinkPackages"
  ;;
pink)
  packages="$packages $GoPackages $NicerDebugPackages"
  ;;
*)
  die "unknown build package selection: '${PT_VARIANT}'"
  ;;
esac

packages="$(printf '%s\n' "$packages" | xargs -n 1 | sort -u | xargs)"

case $packages in
*python*)
  test -f "etc/py-requirements-${PT_VARIANT}.txt" || die "missing etc/py-requirements-${PT_VARIANT}.txt"
  ;;
esac

# Deliberately not quoted; bare shell, no arrays, want expansion.
# shellcheck disable=SC2086
run apk add --no-cache $packages

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~8< User setup >8~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~8< Trust Stores >8~~~~~~~~~~~~~~~~~~~~~~~~~~~
# GnuPG stuff isolated to "if have gpg command"

if [ -d pkix ]; then
  run mkdir -pv /usr/local/share/ca-certificates
  run cp -v pkix/*.crt /usr/local/share/ca-certificates/./
  run update-ca-certificates
fi

# ~~~~~~~~~~~~~~~~~~~~~~~~~~8< System tuning >8~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Per docker-library/docker, persuade Go code to play with Docker hacks
[ -e /etc/nsswitch.conf ] || echo 'hosts: files dns' >/etc/nsswitch.conf

# ~~~~~~~~~~~~~~~~~~~~8< Per-command setup scripts >8~~~~~~~~~~~~~~~~~~~~~

for section in go python gpg; do
  if have_cmd "$section"; then
    "$progdir/alpine-heavy-${section}.sh" "$@"
  else
    warn "no '${section}' command, skipping its setup"
  fi
done

# Skipping "heroku": requires node runtime
# Consider:
#  * kubernetes

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~8< User config >8~~~~~~~~~~~~~~~~~~~~~~~~~~~~

for F in /tmp/etc/dot.*; do
  install -o "${RUNTIME_USER}" -m 0600 "$F" "/home/${RUNTIME_USER}/${F##*/dot}"
done

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~8< Cleanup >8~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

rm -v /var/cache/apk/*
cd /tmp
rm -rf pkix tools etc
