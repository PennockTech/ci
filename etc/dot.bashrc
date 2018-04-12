# ~/.bashrc
# Control flow, assuming invoked as bash without --posix:
#  login:              /etc/profile
#  login:              first_found( ~/.bash_profile ~/.bash_login ~/.profile )
#  interactive-!login: ~/.bashrc
#  #!|!interactive:    if [ -n "$BASH_ENV" ]; then . "$BASH_ENV"; fi (no $PATH)
#  <use>
#  login:              ~/.bash_logout

# PS4='+[\D{%M:%S}]${BASH_SOURCE}:${LINENO}> '
# exec 4> "${TMPDIR:-/tmp}/trace-bash.$$.log"
# BASH_XTRACEFD=4
# set -x

[[ -n "${INHERIT_ENV:-}" ]] && return 0

shopt -s extglob   # extended globs, with pattern lists

have_cmd() {
  local p
  local c="$1"
  shift
  local oIFS
  oIFS="$IFS" ; IFS=":" ; set $PATH ; IFS="$oIFS"; unset oIFS
  for p
  do
    [ -x "$p/$c" ] && return 0
  done
  return 1
}

# bash still doesn't have `interactive` as an option which can be tested
# by [[ -o optname ]], but does have `i` in `$-`;
# [[ -n "${PS1:-}" ]] is plan B.
#
# Note that .bashrc is _only_ for interactive by default, so this is a relic
# guard; I thought it used to be sourced non-interactively?
if [[ $- == *i* ]]; then

  # \l is only the basename so with a dir for pts, we get a confusing `1`
  # thus skip :\l ; no conditional expansions for SIGfoo etc
  #PS1='$?:\u@\h[\A](\!)\w\$ '
  if have_cmd tput; then
    c_green="$(tput setaf 2)"
    c_yellow="$(tput setaf 3)"
    c_cyan="$(tput setaf 6)"
    c_reset="$(tput sgr0)"
  else
    # no curses, assume ANSI.  Use just AF reset instead of sgr0.
    c_green=$'\e[32m' c_yellow=$'\e[33m' c_cyan=$'\e[36m' c_reset='\e[m'
  fi
  PS1='$?:\['"$c_green"'\]\u\['"$c_reset"'\]@\['"$c_yellow"'\]\h\['"$c_reset"'\][\A](\!)\['"$c_cyan"'\]\w\['"$c_reset"'\]\$ '
  unset c_green c_yellow c_cyan c_reset

  # Avoid storing in history lines starting with space:
  HISTCONTROL='ignorespace'

  alias ..='cd ..'

  typeset -a _e
  _e=('LC_COLLATE=C')
  _o=''
  if [[ $OSTYPE == @(freebsd|darwin)* ]]; then
    [[ $TERM == xterm && $OSTYPE == darwin* ]] && _e+=('TERM=xterm-color')
    _o='-bCFGTW'
    [[ $OSTYPE == freebsd* ]] && _o="${_o}o"
    [[ $OSTYPE == darwin* ]] && _o="${_o}O"
    alias @='cd "`/bin/pwd -P 2>/dev/null || pwd`"'
  elif [[ $(ls --version 2>/dev/null) == *GNU* ]]; then
    _o='--color=tty --time-style=long-iso -bCFv'
    alias @='cd "`/bin/pwd 2>/dev/null || pwd`"'
  else
    alias @='cd "`/bin/pwd 2>/dev/null || pwd`"'
  fi
  eval "function l { $_e ls $_o \"\$@\" ; }"
  unset _o _e

fi

[[ -r ~/.personal/share/container_detect.sh ]] && source ~/.personal/share/container_detect.sh

# vim: set ft=sh sw=2 et :
