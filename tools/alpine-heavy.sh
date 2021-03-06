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
readonly CriticalPackages="openssl curl jq git openssh-client su-exec"
readonly GoPackages="go musl-dev bash make" # bash/make for building local Go
readonly NicerDebugPackages="zsh tar socat pcre-tools chrpath less file strace binutils"
readonly PythonPackages="gcc make linux-headers libffi libffi-dev python3 python3-dev py-pip"
readonly DNSPackages="unbound unbound-libs unbound-dev bind-tools ldns-tools drill"
readonly CryptoPackages="openssl gnutls-utils gnupg"
readonly RepoPackages="git mercurial"
# Removed from RepoPackages:
#   2020-01-27 github-cli : aport gone, <https://gitlab.alpinelinux.org/alpine/aports/commit/1898033c5f9e95dcee43f95e1d1671adbbd6b022>
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
  bash zsh vim groff mandoc
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

# RUNTIME_SUPGIDS='100 101 102' or RUNTIME_SUPGIDS='200:foo 100'
for gid_pair in $RUNTIME_SUPGIDS; do
  # Alpine won't take a gid, it needs a name.  But the specified
  # gid might not exist, so let it be "created if not already present, using
  # supplied name hint".  This doesn't affect the defaults, but can impact some
  # build-arg override values.
  gid="${gid_pair%%:*}"
  if gline="$(getent group "$gid")"; then
    gname="${gline%%:*}"
    run adduser "$RUNTIME_USER" "$gname"
  elif [ "$gid" != "$gid_pair" ]; then
    gname="${gid_pair#*:}"
    run addgroup -g "$gid" "$gname"
    run adduser "$RUNTIME_USER" "$gname"
  else
    die "Unknown group for supplemental GID $gid [from: $RUNTIME_SUPGIDS]"
  fi
done

# /run is not tmpfs inside Docker by default, so provide something which
# will work for common modern layouts.  For the XDG guidelines: we define
# the duration of the user's login as the lifetime of the container.
mkdir -pv /run/user/0 "/run/user/${RUNTIME_UID}"
chown "${RUNTIME_UID}:${RUNTIME_GID}" "/run/user/${RUNTIME_UID}"

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

# There's no need to make these files unreadable by other users in the container
for F in /tmp/etc/dot.*; do
  install -o "${RUNTIME_USER}" -m 0644 "$F" "/home/${RUNTIME_USER}/${F##*/dot}"
done

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~8< Cleanup >8~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

rm -v /var/cache/apk/*
cd /tmp
rm -rf pkix tools etc
