#!/bin/echo you_should_source_me
# shellcheck shell=sh disable=SC2034,SC2039,SC3043
#
# Copyright © 2018,2019,2020,2021 Pennock Tech, LLC.
# All rights reserved, except as granted under license.
# Licensed per file LICENSE.txt

# Correct sourcing, for scripts in same directory:
#
#   top_arg0="$0"
#   # shellcheck source=tools/lib.sh
#   . "$(dirname "$0")/lib.sh"
#
# If using bash/zsh/most shells (but not dash) then:
#
#   # shellcheck source=tools/lib.sh
#   . "$(dirname "$0")/lib.sh" "$0" "$@"
#
# We expect, beyond POSIX:
#  * The 'local' builtin to exist and work

# This file exists in PT's CI & Packer repos, as lib.sh in appropriate places.

# Shellcheck disabling rationale:
#  SC2034: we're a lib.sh, we define things which are unused herein, that's
#          part of the point.
#  SC2039: we use local, POSIX or not [this use-case split out into 3043]
#  SC3043: we use local, POSIX or not [should remove SC2039 from exclude list when confident all checkers are sufficiently up-to-date]

set -eu
if [ -n "${top_arg0:-}" ]; then
  # caller is using a shell which doesn't pass params to source, so their argv is our argv
  true
else
  top_arg0="${1:?missing argv0 from caller}"
  shift
fi

# nb: busybox basename doesn't use the -s .sh form, only suffix as second
#     non-flag param
progname="$(basename "$top_arg0" .sh)"
progname_full="$(basename "$top_arg0")"
progdir="$(dirname "$top_arg0")"
startdir="$(pwd)"

# shell portability tests
if [ -n "${ZSH_VERSION:-}" ] || [ -n "${BASH_VERSION:-}" ]; then
  readonly SHHAVE_DECLARE=true
  readonly SHHAVE_LOCAL_I=true
else
  readonly SHHAVE_DECLARE=false
  readonly SHHAVE_LOCAL_I=false
fi

# Let the caller override name/path/whatever, eg to build with a different
# version of Go.
: "${GIT_CMD:=git}"
: "${GO_CMD:=go}"
: "${DOCKER_CMD:=docker}"
: "${GREP_CMD:=grep}"
: "${GPG_CMD:=gpg}"

# Standard exit code values {{{
# sysexits.h (I mostly use EX_USAGE in my code)
readonly EX_USAGE=64 EX_DATAERR=65 EX_NOINPUT=66 EX_NOUSER=67 EX_NOHOST=68 EX_UNAVAILABLE=69 EX_SOFTWARE=70
readonly EX_OSERR=71 EX_OSFILE=72 EX_CANTCREAT=73 EX_IOERR=74 EX_TEMPFAIL=75 EX_PROTOCOL=76 EX_NOPERM=77 EX_CONFIG=78
# SUSv4 XCU 2.8.2
readonly EX_CMD_NOT_EXECUTABLE=126 EX_CMD_NOT_FOUND=127
# Common
readonly EX_TIMEOUT=124
# Standard exit code values }}}

# Wrapper functions for overridden commands {{{
git() { command "$GIT_CMD" "$@"; }
go() { command "$GO_CMD" "$@"; }
docker() { command "$DOCKER_CMD" "$@"; }
gpg() { command "$GPG_CMD" "$@"; }

grep() { LC_ALL=C GREP_OPTIONS='' command "$GREP_CMD" "$@"; }
egrep() { LC_ALL=C GREP_OPTIONS='' command "$GREP_CMD" -E "$@"; }
fgrep() { LC_ALL=C GREP_OPTIONS='' command "$GREP_CMD" -F "$@"; }

# Wrapper functions for overridden commands }}}

# Color/colour support {{{

if $SHHAVE_DECLARE; then
  # We're guarded against shell not having declare, so:
  # shellcheck disable=SC3044
  declare -i want_color_int
fi
want_color_int=0
if [ -n "${CLICOLOR_FORCE:-}" ] && [ "$CLICOLOR_FORCE" != "0" ]; then
  want_color_int=1
elif [ -n "${CLICOLOR:-}" ] && [ "$CLICOLOR" != "0" ] && [ -t 1 ]; then
  want_color_int=1
fi
if [ -n "${NO_COLOR:-${NOCOLOR:-}}" ]; then
  want_color_int=0
fi

# Color/colour support }}}

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
  if [ $want_color_int -eq 0 ] && [ -n "${NO_EMOJI:-${NOEMOJI:-}}" ]; then
    printf >&2 '%s: %s\n' "$progname" "$*"
  elif [ -n "${NO_EMOJI:-${NOEMOJI:-}}" ]; then
    # shellcheck disable=SC1117
    printf >&2 "\033[${color}m%s: \033[1m%s\033[0m\n" "$progname" "$*"
  elif [ $want_color_int -eq 0 ]; then
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
  if [ -n "${NO_COLOR:-${NOCOLOR:-}}" ] && [ -n "${NO_EMOJI:-${NOEMOJI:-}}" ]; then
    printf >&2 '%s: ' "$progname"
    # shellcheck disable=SC2059
    printf >&2 "$@"
    printf >&2 '\n'
  elif [ -n "${NO_EMOJI:-${NOEMOJI:-}}" ]; then
    # shellcheck disable=SC1117
    printf >&2 "\033[${color}m%s: \033[1m" "${progname}"
    # shellcheck disable=SC2059
    printf >&2 "$@"
    printf >&2 '\033[0m\n'
  elif [ -n "${NO_COLOR:-${NOCOLOR:-}}" ]; then
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

: "${PTLIB_PREFIX_SYMBOL_INFO:=✅}"
: "${PTLIB_PREFIX_SYMBOL_WARN:=⚠️ }"
: "${PTLIB_PREFIX_SYMBOL_DIE:=❌}"
: "${PTLIB_PREFIX_SYMBOL_V_0:=🚩}"
: "${PTLIB_PREFIX_SYMBOL_V_1:=🗣️}"
: "${PTLIB_PREFIX_SYMBOL_V_2:=🎺}"
: "${PTLIB_PREFIX_SYMBOL_V_3:=📢}"
: "${PTLIB_PREFIX_SYMBOL_V_COUNT:=3}"
: "${PTLIB_PREFIX_SYMBOL_V_REST:=🙊}"

info() {
  local PREFIX_SYMBOL="${PTLIB_PREFIX_SYMBOL_INFO?}"
  _stderr_colored "${PTLIB_COLOR_INFO:-32}" "$@"
}

warn() {
  local PREFIX_SYMBOL="${PTLIB_PREFIX_SYMBOL_WARN?}"
  _stderr_colored "${PTLIB_COLOR_WARN:-31}" "$@"
  bump_warn_count
}

warn_multi() {
  local PREFIX_SYMBOL="${PTLIB_PREFIX_SYMBOL_WARN?}"
  local x
  for x; do
    _stderr_colored "${PTLIB_COLOR_WARN:-31}" "$x"
  done
  bump_warn_count
}

die() {
  local PREFIX_SYMBOL="${PTLIB_PREFIX_SYMBOL_DIE?}"
  [ $# -ge 1 ] || set -- "dying for unknown reason"
  _stderr_colored "${PTLIB_COLOR_DIE:-31}" "$@"
  exit 1
}

die_n() {
  local ev="${1:?need an exit value}"
  shift
  [ $# -ge 1 ] || set -- "dying for unknown reason"
  local PREFIX_SYMBOL="${PTLIB_PREFIX_SYMBOL_DIE?}"
  _stderr_colored "${PTLIB_COLOR_DIE:-31}" "$@"
  exit "$ev"
}

die_multi() {
  local PREFIX_SYMBOL="${PTLIB_PREFIX_SYMBOL_DIE?}"
  local x
  for x; do
    _stderr_colored "${PTLIB_COLOR_DIE:-31}" "$x"
  done
  exit 1
}

verbose_n() {
  [ "$VERBOSE" -ge "$1" ] || return 0
  local verbosity="$1"
  shift
  local tag
  if [ "$verbosity" -ge 0 ] && [ "$verbosity" -le "${PTLIB_PREFIX_SYMBOL_V_COUNT:?}" ]; then
    tag="PTLIB_PREFIX_SYMBOL_V_$verbosity"
  else
    tag="PTLIB_PREFIX_SYMBOL_V_REST"
  fi
  if [ -n "${BASH_VERSION:-}" ]; then
    local -n PREFIX_SYMBOL="$tag"
  elif [ -n "${ZSH_VERSION:-}" ]; then
    local PREFIX_SYMBOL="${(P)tag}"
  else
    local PREFIX_SYMBOL='?'
  fi
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
  _stderr_colored "${PTLIB_COLOR_WARN:-31}" "$@" 2>>"$warn_repeat_at_exit_file"
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

if [ -n "${NO_TERMTITLE:-${NO_XTITLE:-}}" ]; then
  xtitle() { : ; }
  xtitlef() { : ; }
else
  case $TERM in
    # NB: shellcheck SC2059 is about using variables in printf strings ...
    # which is exactly the point of the xtitlef function: the *f variant
    # takes a format string as a parameter.
  (putty|xterm*)
    xtitle() { printf >/dev/tty '\e]2;%s\a' "$*"; }
    # shellcheck disable=SC2059
    xtitlef() { local p="${1:?}"; shift; printf >/dev/tty '\e]2;'"$p"'\a' "$@"; }
    ;;
  (screen*)
    # Don't care about return value or less than ideal title
    # shellcheck disable=SC2155
    xtitle() { local t="$(printf '%s\n' "$*" | tr -cd 'A-Za-z0-9.,:;!@#$%^&*()[]{}|~_+-- ')"; printf >/dev/tty '\e]2;%s\a' "$t"; }
    # shellcheck disable=SC2059
    xtitlef() { local p="${1:?}"; shift; printf >/dev/tty '\e]2;'"$p"'\a' "$@"; }
    ;;
  (*)
    xtitle() { : ; }
    xtitlef() { : ; }
    ;;
  esac
fi

# Tracing Functions }}}

# Tracing Run Wrapping Functions {{{

# `run a -b c` invokes `a -b c` unless $NOT_REALLY; it has various messaging options
# To permit those messages to be seen even while the command itself is run with stdio
# redirected, run optionally starts with `-tune` flags, before the actual command.
run() {
  local prefix='' suffix_msg=''
  local close_all=false close_stderr=false
  while [ "$#" -gt 0 ]; do
    case "${1:?need something to run}" in
      # known bug/limitation here that I'm not bothering to collect multiple messages
      -nostderr) shift; close_stderr=true; suffix_msg='No stderr' ;;
      -noio) shift; close_all=true; suffix_msg='No I/O' ;;
      --) shift; break ;;
      *) break ;;
    esac
  done
  suffix_msg="${suffix_msg:+[}${suffix_msg:-}${suffix_msg:+]}"
  : "${1:?need something to run}"
  if [ -n "${NOT_REALLY:-}" ]; then
    if [ -n "${run_state_label:-}" ]; then
      prefix="${run_state_prelabel:-}${run_state_label:-}${run_state_postlabel:-} "
    fi
    verbose_n 0 "${prefix}would invoke:" "$*" "$suffix_msg"
  else
    verbose_n 2 invoking: "$*"
    if $close_all; then
      "$@" </dev/null >/dev/null 2>&1
    elif $close_stderr; then
      "$@" 2>/dev/null
    else
      "$@"
    fi
  fi
}

retry_n_run() { retry_whileexit_e_n_run -1 "$@"; }

retry_whileexit_e_n_run() {
  if "$SHHAVE_LOCAL_I"; then
    local -i max_runs retry_on_exitstatus
    local -i iter_count=0 ev=0 entry_warn_count="$warn_count"
  else
    local max_runs retry_on_exitstatus
    local iter_count=0 ev=0 entry_warn_count="$warn_count"
  fi
  retry_on_exitstatus="$1"
  max_runs="$2"
  [ "$max_runs" -gt 0 ] || die "invocation error, retry_n_run first param should be positive int [got: $1]"
  shift 2
  local prefix warn_suffix
  if [ -n "${NOT_REALLY:-}" ]; then
    if [ -n "${run_state_label:-}" ]; then
      prefix="${run_state_prelabel:-}${run_state_label:-}${run_state_postlabel:-} "
    else
      prefix=''
    fi
    verbose_n 0 "${prefix}would invoke:" "$*"
    return
  fi
  verbose_n 2 invoking: "$*"
  while [ "$iter_count" -lt "$max_runs" ]; do
    ev=0
    "$@" || ev="$?"
    if [ "$ev" -eq 0 ] && [ "$retry_on_exitstatus" -ne 0 ]; then
      warn_count="$entry_warn_count"  # it's not an exit warn event if a passphrase was entered incorrectly
      return 0
    fi
    # To retry _always_, call with the guard as -1
    if [ "$retry_on_exitstatus" -ge 0 ] && [ "$ev" -ne "$retry_on_exitstatus" ]; then
      warn "command failed [$ev] $1 -- only retrying if exits [$retry_on_exitstatus], aborting"
      return "$ev"
    fi
    iter_count=$((iter_count + 1))
    if [ "$iter_count" -lt "$max_runs" ]; then
      warn_suffix="try $iter_count/$max_runs - will retry"
    else
      warn_suffix="failed $max_runs times, aborting"
    fi
    warn "command failed [$ev] $1 -- $warn_suffix"
  done
  return "$ev"
}

# Tracing Run Wrapping Functions }}}

# Env Setup & Testing {{{

: "${HOME:=/home/$(id -un)}"
export HOME
# Cautious about unilaterally exporting GOPATH as it looks like the vgo module
# approach is moving away from that.  So we want to grab _a_ GOPATH, but not
# exported.
local_GOPATH="${GOPATH:-${HOME}/go}"
firstGopath="${local_GOPATH%%:*}"

LOCAL_OS="$(uname)"
LOCAL_OS_LOWER="$(printf '%s' "$LOCAL_OS" | tr A-Z a-z)"
LOCAL_ARCH="$(arch || uname -m)"
case "$LOCAL_ARCH" in
  x86_64) GOCOMPAT_ARCH=amd64 ;;
  aarch64) GOCOMPAT_ARCH=arm64 ;;
  # armv7l is for RPi; Go itself distributes armv6l as a variant, but which we need for any given package varies a lot more
  *) GOCOMPAT_ARCH="$LOCAL_ARCH" ;;
esac
# Stuff written in Go will have release artifacts _typically_ named with one or
# the other of these two variants:
WANT_OS_ARCH_DASH="${LOCAL_OS_LOWER}-${GOCOMPAT_ARCH}"
WANT_OS_ARCH_US="${LOCAL_OS_LOWER}_${GOCOMPAT_ARCH}"

: "${DOCKER_GOOS:=linux}"
export DOCKER_GOOS

# In this block, unless stated otherwise, shellcheck disables are for portability
# complaints about code which we're portability-guarding.
if [ -n "${ZSH_VERSION:-}" ]; then
  if zmodload zsh/parameter; then
    # shellcheck disable=SC3006,SC2154
    have_cmd() { (( $+commands[$1] )); }
  else
    have_cmd() { whence -p "$1" >/dev/null; }
  fi
elif [ -n "${BASH_VERSION:-}" ]; then
  # shellcheck disable=SC3045
  have_cmd() { type -P "$1" >/dev/null; }
else
  # command -v is in modern POSIX
  have_cmd() { command -v "$1" >/dev/null; }
fi

# Env Setup & Testing }}}

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
