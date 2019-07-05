#!/bin/echo you_should_source_me
# shellcheck shell=sh disable=SC2034,SC2039
#
# Copyright © 2018,2019 Pennock Tech, LLC.
# All rights reserved, except as granted under license.
# Licensed per file LICENSE.txt

# Correct sourcing, for scripts in same directory:
#
#   # shellcheck source=tools/lib.sh
#   . "$(dirname "$0")/lib.sh" "$0" "$@"
#
# If /bin/sh is dash, then the script will need to be bash or other "slightly
# more than POSIX" shell.  We only expect: `local` to work, and `source` to
# pass along arguments.

# This file exists in PT's CI & Packer repos, as lib.sh in appropriate places.

# Shellcheck disabling rationale:
#  SC2034: we're a lib.sh, we define things which are unused herein, that's
#          part of the point.
#  SC2039: we use local, POSIX or not.

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

# Verbose must be a non-negative integer
if [ -n "${VERBOSE:-}" ]; then
  case ${VERBOSE} in
  *[!0-9]*) VERBOSE=1 ;;
  *) VERBOSE=$((0 + VERBOSE)) ;;
  esac
else
  VERBOSE=0
fi

warn_count=0
warn_repeat_at_exit_file=''
bump_warn_count() { warn_count=$((warn_count + 1)); }

_stderr_colored() {
  # Rationale for shellcheck disables:
  #   SC1117: it's a "prefer", we are correct in what we have, and changing
  #           would make the code less readable, not more.
  #
  local color="$1"
  shift
  if [ -n "${NOCOLOR:-}" ] && [ -n "${NOEMOJI:-}" ]; then
    printf >&2 '%s: %s\n' "$progname" "$*"
  elif [ -n "${NOEMOJI:-}" ]; then
    # shellcheck disable=SC1117
    printf >&2 "\033[${color}m%s: \033[1m%s\033[0m\n" "$progname" "$*"
  elif [ -n "${NOCOLOR:-}" ]; then
    # shellcheck disable=SC1117
    printf >&2 "${PREFIX_SYMBOL:-}${PREFIX_SYMBOL:+ }%s: %s\n" "$progname" "$*"
  else
    # shellcheck disable=SC1117
    printf >&2 "${PREFIX_SYMBOL:-}${PREFIX_SYMBOL:+ }\033[${color}m%s: \033[1m%s\033[0m\n" "$progname" "$*"
  fi
}

_stderr_coloredf() {
  # Rationale for shellcheck disables:
  #   SC1117: it's a "prefer", we are correct in what we have, and changing
  #           would make the code less readable, not more.
  #   SC2059: we are explicitly using a var in printf first-param because we're
  #           a <something>f() pass-thru
  #
  local color="$1"
  shift
  if [ -n "${NOCOLOR:-}" ] && [ -n "${NOEMOJI:-}" ]; then
    printf >&2 '%s: ' "$progname"
    # shellcheck disable=SC2059
    printf >&2 "$@"
    printf >&2 '\n'
  elif [ -n "${NOEMOJI:-}" ]; then
    # shellcheck disable=SC1117
    printf >&2 "\033[${color}m%s: \033[1m" "${progname}"
    # shellcheck disable=SC2059
    printf >&2 "$@"
    printf >&2 '\033[0m\n'
  elif [ -n "${NOCOLOR:-}" ]; then
    # shellcheck disable=SC1117
    printf >&2 "${PREFIX_SYMBOL:-}${PREFIX_SYMBOL:+ }%s: " "$progname"
    # shellcheck disable=SC2059
    printf >&2 "$@"
    printf >&2 '\n'
  else
    # shellcheck disable=SC1117
    printf >&2 "${PREFIX_SYMBOL:-}${PREFIX_SYMBOL:+ }\033[${color}m%s: \033[1m" "$progname"
    # shellcheck disable=SC2059
    printf >&2 "$@"
    printf >&2 '\033[0m\n'
  fi
}

info() {
  local PREFIX_SYMBOL='✅'
  _stderr_colored 32 "$@"
}

warn() {
  local PREFIX_SYMBOL='⚠️ '
  _stderr_colored 31 "$@"
  bump_warn_count
}

warn_multi() {
  local PREFIX_SYMBOL='⚠️'
  local x
  for x; do
    _stderr_colored 31 "$x"
  done
  bump_warn_count
}

die() {
  local PREFIX_SYMBOL='❌'
  _stderr_colored 31 "$@"
  exit 1
}

die_multi() {
  local PREFIX_SYMBOL='❌'
  local x
  for x; do
    _stderr_colored 31 "$x"
  done
  exit 1
}

verbose_n() {
  [ "$VERBOSE" -ge "$1" ] || return 0
  local verbosity="$1"
  shift
  local PREFIX_SYMBOL
  case "$verbosity" in
  1) PREFIX_SYMBOL='🗣️ ' ;;
  2) PREFIX_SYMBOL='🎺' ;;
  3) PREFIX_SYMBOL='📢' ;;
  *) PREFIX_SYMBOL='🙊' ;;
  esac
  _stderr_colored 36 "$@"
}

verbose() { verbose_n 1 "$@"; }

warn_setup_repeat_at_exit() {
  # We're sh, not bash, so we don't have arrays, so use a tempfile,
  # which we might well leak since we can't rely upon a stack of cleanup
  # functions (or should we, using this lib?).
  # We'll just have to live with that.
  warn_repeat_at_exit_file="$(mktemp "${TMPDIR:-/tmp}/warnings.$progname.XXXXXXXXXX")"
}

repeat_at_exit_warn() {
  [ -n "$warn_repeat_at_exit_file" ] || warn_setup_repeat_at_exit
  warn "$@"
  _stderr_colored 31 "$@" 2>>"$warn_repeat_at_exit_file"
}

# call "report_exit -0" to exit 1 if warnings, else 0
report_exit() {
  if [ "$warn_count" -gt 0 ]; then
    warn "saw ${warn_count} warnings"
    if [ -n "$warn_repeat_at_exit_file" ]; then
      cat >&2 <"$warn_repeat_at_exit_file"
      rm -f -- "$warn_repeat_at_exit_file"
    fi
    if [ ".${1:-}" = ".-0" ]; then
      exit 1
    fi
  elif [ -n "$warn_repeat_at_exit_file" ]; then
    rm -f -- "$warn_repeat_at_exit_file"
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

if have_cmd "$GIT_CMD" && git_is_inside_worktree "$progdir" 2>/dev/null; then
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
# true during docker|packer build, for the duration of that build.

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
