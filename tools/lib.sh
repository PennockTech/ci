#!/bin/echo you should source me
# shellcheck shell=sh
#
# Copyright © 2018 Pennock Tech, LLC.
# All rights reserved, except as granted under license.
# Licensed per file LICENSE.txt

# Correct sourcing, for scripts in same directory:
#
#   . "$(dirname "$0")/lib.sh" "$0" "$@"

set -eu
top_arg0="${1:?missing argv0 from caller}"
shift

# nb: busybox basename doesn't use the -s .sh form, only suffix as second
#     non-flag param
progname="$(basename "$top_arg0" .sh)"
progdir="$(dirname "$top_arg0")"
startdir="$(pwd)"

# Let the caller override name/path/whatever, eg to build with a different
# version of Go.
: "${GIT_CMD:=git}"
: "${GO_CMD:=go}"
: "${DEP_CMD:=dep}"
: "${DOCKER_CMD:=docker}"
: "${GREP_CMD:=grep}"
: "${GPG_CMD:=gpg}"

# Wrapper functions for overridden commands {{{
git() { command "$GIT_CMD" "$@"; }
go() { command "$GO_CMD" "$@"; }
dep() { command "$DEP_CMD" "$@"; }
docker() { command "$DOCKER_CMD" "$@"; }
gpg() { command "$GPG_CMD" "$@"; }

grep() { LC_ALL=C GREP_OPTIONS='' command "$GREP_CMD" "$@"; }
egrep() { LC_ALL=C GREP_OPTIONS='' command "$GREP_CMD" -E "$@"; }
fgrep() { LC_ALL=C GREP_OPTIONS='' command "$GREP_CMD" -F "$@"; }

# Wrapper functions for overridden commands }}}

# Tracing Functions {{{

: "${VERBOSE:=0}"
warn_count=0
bump_warn_count() { warn_count=$((warn_count + 1)); }

_stderr_colored() {
  local color="$1"
  shift
  if [ -n "${NOCOLOR:-}" ]; then
    printf >&2 '%s: %s\n' "$progname" "$*"
  else
    # shellcheck disable=SC1117
    printf >&2 "\033[${color}m%s: \033[1m%s\033[0m\n" "$progname" "$*"
  fi
}

info() { _stderr_colored 32 "$@"; }

warn() {
  _stderr_colored 31 "$@"
  bump_warn_count
}

warn_multi() {
  local x
  for x; do
    _stderr_colored 31 "$x"
  done
  bump_warn_count
}

die() {
  _stderr_colored 31 "$@"
  exit 1
}

die_multi() {
  local x
  for x; do
    _stderr_colored 31 "$x"
  done
  exit 1
}

verbose_n() {
  [ "$VERBOSE" -ge "$1" ] || return 0
  shift
  _stderr_colored 36 "$@"
}

verbose() { verbose_n 1 "$@"; }

# call "report_exit -0" to exit 1 if warnings, else 0
report_exit() {
  if [ "$warn_count" -gt 0 ]; then
    warn "saw ${warn_count} warnings"
    if [ ".${1:-}" = ".-0" ]; then
      exit 1
    fi
  fi
  exit "${1:-0}"
}

run() {
  if [ -n "${NOT_REALLY:-}" ]; then
    verbose_n 0 would invoke: "$*"
  else
    verbose_n 2 invoking: "$*"
    "$@"
  fi
}

# Tracing Functions }}}

: "${HOME:=/home/$(id -un)}"
export HOME
# Cautious about unilaterally exporting GOPATH as it looks like the vgo module
# approach is moving away from that.  So we want to grab _a_ GOPATH, but not
# exported.
local_GOPATH="${GOPATH:-${HOME}/go}"
firstGopath="${local_GOPATH%%:*}"

LOCAL_OS="$(uname)"
: "${DOCKER_GOOS:=linux}"
export DOCKER_GOOS

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

# Git Utilities {{{

# This seems simple enough, but when invoked from a git hook, GIT_DIR=.git is
# in environ, which (1) breaks cryptically when using `git -C $somedir` because
# the explicit $GIT_DIR is not in that directory, and (2) even if we resolved
# GIT_DIR to be absolute at the start of this lib, that would still break this
# test.  So we want a locally unset GIT_DIR just for this check.
git_is_inside_worktree() {
  local check_dir="${1:?}"
  local output
  output="$(
    unset GIT_DIR
    git -C "$check_dir" rev-parse --is-inside-work-tree
  )"
  [ "${output:-.}" = "true" ]
}

if have_cmd "$GIT_CMD" && git_is_inside_worktree "$progdir"; then
  have_git=true
  REPO_ROOT="$(
    unset GIT_DIR
    git -C "$progdir" rev-parse --show-toplevel
  )"

  cd_to_repo_root() {
    cd "$(
      unset GIT_DIR
      git -C "$progdir" rev-parse --show-toplevel
    )"
  }

  lgit() { git -C "$REPO_ROOT" "$@"; }
else
  have_git=false
fi

# Git Utilities }}}

# Retrieval Utilities {{{

# These utilities assume that there are no untrusted users in /tmp, which is
# true during docker build, for the duration of that build.

download_to_tmp() {
  local url="${1:?need a URL}" lfn="${2:?need a local filename}"
  info "Retrieving <$url>"
  run curl -fsSLo "/tmp/$lfn" "${url}"
}

download_to_tmp_sha256() {
  have_cmd sha256sum || die "missing sha256sum tool"
  local url="${1:?need a URL}" lfn="${2:?need a local filename}" sum="${3:?need a SHA2/256 checksum}"
  local previous sumfn
  sumfn="/tmp/cksum.$lfn"
  previous="$(pwd)"

  echo "$sum *${lfn}" >"$sumfn"
  download_to_tmp "$url" "$lfn"
  cd /tmp
  sha256sum -c "$sumfn"
  rm -v "$sumfn"
  cd "$previous"
}

# Retrieval Utilities }}}

# vim: set foldmethod=marker :
