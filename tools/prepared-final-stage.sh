#!/bin/sh -eu
#
# This is copied into the root-stage image in the run-time user's directory
# and invoked for the non-root-stage build.
# It does not have lib.sh available.
#
# CWD should be runtime user's homedir.

PGP_FILES='
  pgp-philpennock-2013.asc:ACBB4324393ADE3515DA2DDA4D1E900E14C1CC04
  pgp-philpennock-2020.asc:4833892924C60A7AE666D32A1DA3E68F41CEECAC
  '

have_cmd() {
  local p oIFS c
  c="$1"
  shift
  oIFS="$IFS"
  IFS=":"
  # shellcheck disable=SC2086
  set $PATH
  IFS="$oIFS"
  for p; do
    [ -x "$p/$c" ] && return 0
  done
  return 1
}

if have_cmd gpg; then
  for entry in $PGP_FILES; do
    fn="etc/pgp-keys/${entry%:*}"
    expected_key="${entry#*:}"
    gpg </dev/null --batch --import "$fn"
    echo "${expected_key}:6:" | gpg --import-ownertrust
    gpg --check-trustdb
    # NB: TOFU requires GnuPG built with sqlite support, which is not the case
    # for Alpine's package today.
    gpg --tofu-policy good "${expected_key}" || echo >&2 "(ignoring missing TOFU support)"
  done
else
  echo >&2 "NOTICE: missing gpg command in this image, skipping gpg setup"
fi
