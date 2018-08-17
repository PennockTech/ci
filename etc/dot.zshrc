# Reduced .zshrc for standalone usage
# Is copied to various places for use by root and non-root users.
# Is copied into the base-image of jails, where the run-time has $HOME
# read-only.
#
# We avoid version-guards and (even more) complexity, as this variant
# is only used on systems where I keep the shell up-to-date.

# Debugging & "home"-dir {{{

# .zshenv -> .zprofile -> .zshrc -> .zlogin
# Tracing example:
#PS4='+[%D{%M:%S}]%N:%i> '
#setopt xtrace
#exec 2> "$HOME/pdp-zsh.$$.log"

if [[ -w ~ ]]; then
  zsh_writable="$HOME/."
elif [[ $UID -eq 0 ]]; then
  d="/var/run/.root.zsh"
  if [[ -d "$d" ]] || mkdir -m 0700 "$d" ; then zsh_writable="$d/"; fi
  unset d
else
  zsh_writable=''
fi

if [[ -w ~ ]]; then
  [[ -d ~/.cache ]] || mkdir -m 0700 "$HOME/.cache"
else
  base=/var/tmp
  newbase() { base="$1"; return 1; }
  try() {
    local d
    d="${base:?}/cache.${LOGNAME:?}${1}"
    if [[ -d "$d" ]]; then
      if [[ -O "$d" ]]; then
        cache_dir="$d"
        return 0
      fi
      return 1
    fi
    mkdir -m 0700 -- "$d"
    if [[ -d "$d" && -O "$d" ]]; then
      cache_dir="$d"
      return 0
    fi
    return 1
  }
  failed=false
  try "" || try ".0" || try ".1" || try ".$RANDOM" || newbase /tmp || try "" || try ".$RANDOM" || failed=true
  if $failed; then
    print -u2 "${0:t}: search for cache dir failed"
  else
    export XDG_CACHE_HOME="${cache_dir:?}"
  fi
  unset cache_dir failed base
  unfunction try newbase
fi

# Debugging & "home"-dir }}}

# Options & Modules {{{

setopt autocd extended_glob numeric_glob_sort interactive_comments
# see also HIST vars below; file mgmt:
setopt append_history extended_history hist_expire_dups_first hist_fcntl_lock
# interactive behavior:
setopt no_bang_hist hist_find_no_dups hist_ignore_space hist_verify

# in particular: hist_ignore_space is critical for security, given my habits,
# when using history files.

{ # any unloadable modules, we don't care
zmodload zsh/attr 				# z{get,set,del,list}attr
[[ $OSTYPE == linux* ]] && zmodload zsh/cap	# POSIX capability mgmt, proc & files
zmodload zsh/datetime				# strftime; $EPOCHSECONDS
zmodload zsh/parameter				# $dirstack, $commands, $functions
zmodload -i zsh/re2 || zmodload -i zsh/pcre	# some kind of better regex
} 2>/dev/null

# Options & Modules }}}

# Container Detection {{{
# ~/.personal/share/container_detect.sh
#
# This must work in: bash zsh

# Variable: IS_CONTAINER
# Exported: always
# If unset: container detection has not been performed
# If empty: not in a container
# Nonempty: in a container; may contain whitespace; first word is most generic type
#
unset IS_CONTAINER
unset container_tl
[[ -n "${ZSH_VERSION:-}" ]] && typeset -aU container_tl
container_tl=()
case $OSTYPE in
  freebsd*)
    [[ $(sysctl -n security.jail.jailed) -gt 0 ]] && container_tl+=( jail )
    ;;
  linux-gnu)
    [[ "$(cat /proc/1/cgroup | cut -d : -f 3 | sort -u)" != "/" ]] && container_tl+=( cgroup )
    # some of these based upon Ubuntu /etc/init/container-detect.conf
    [[ -n "${LIBVIRT_LXC_UUID}" ]] && container_tl+=( lxc-libvirt )
    [[ -d /proc/vz && ! -d /proc/bc ]] && container_tl+=( openvz )
    if [[ ${#container_tl} -eq 1 ]]; then
      _vxid=''
      if [[ -n "${ZSH_VERSION:-}" ]]; then
        _vxid="${${(@Mj::)${(@f):-"$(< /proc/self/status)"}##VxID*}##[![:space:]]##[[:space:]]}"
      else
        _vxid="$(grep '^VxID' /proc/self/status | cut -f2)" || true
      fi
      [[ ${_vxid:-0} -gt 1 ]] && container_tl+=( vserver )
      unset _vxid
    fi
    [[ -f /run/container_type ]] && container_tl+=( $(< /run/container_type) )
    ;;
  *sunos*|*solaris*|*indiana*|*illumos*|*smartos*)
    [[ "$(zonename)" == global ]] || container_tl+=( zone )
    ;;
esac
IS_CONTAINER="${container_tl[@]}"
unset container_tl
[[ -n "${IS_CONTAINER:-}" ]] && export IS_CONTAINER

# TODO: list uniq-ification in bash

# vim: set ft=zsh sw=2 et :
# Container Detection }}}

# Path-type settings {{{

typeset -U path
path[(r).]=()
path=(
  ~/sbin(N/)
  ~/bin(N/)
  ~/.pyenv/shims(N/)
  ~/.pyenv/bin(N/)
  /opt/gotools/bin(N/)
  /usr/local/go/bin(N/)
  /opt/gnupg/sbin(N/) /opt/gnupg/bin(N/)
  "${path[@]}"
  /opt/spodhuis/sbin(N/)
  /opt/spodhuis/bin(N/)
  /opt/exim/bin(N/)
)

typeset -U fpath
fpath=(
  ~/etc/zsh/functions(N/)
  /usr/globnix/share/zsh/site-functions(N/)
  /usr/local/share/zsh/site-functions(N/)
  "${fpath[@]}" )
autoload ${^fpath}/*(N-.:t)

# root should not be invoking compilers on arbitrary paths of retrieved content
# not PGP-verified; other users use this config too so they do get GOPATH
if [[ $UID -gt 0 && -d ~/go ]]; then
  typeset -gxUT GOPATH gopath
  gopath=( ~/go )
  path+=( /usr/local/go/bin(N/) ~/go/bin )
fi

# Roughly equivalent to «eval "$(pyenv init -)"» but MUCH faster:
if [[ -d ~/.pyenv/bin ]] && (( $+commands[pyenv] )); then
  # assume path already modified elsewhere; else prepend ~/.pyenv/shims
  export PYENV_SHELL=zsh PYENV_VIRTUALENV_DISABLE_PROMPT=1
  pyenv() {
    if [[ $# -eq 0 ]]; then
      command pyenv
      return
    fi
    case $1 in
    activate|deactivate|rehash|shell)
      eval "$(pyenv "sh-$1" "${@[2,-1]}")"
      ;;
    *)
      command pyenv "$@"
      ;;
    esac
  }
  cmd=pyenv
  # c for command lookup in path, A to abs resolve, chasing all symlinks
  # remove cmd, remove cmd's dir, tack on the rest
  F=$cmd:c:A:h:h/completions/${cmd}.zsh
  [[ -f "$F" ]] && . "$F"
  unset cmd F
fi

# Path-type settings }}}

# Non-path environ tuning {{{

export LC_CTYPE=en_US.UTF-8
export PAGER='less -FXMQRij5'
unset MAIL || :

if (( $+commands[vim] )); then
  export EDITOR=vim VISUAL=vim
  alias vi=vim
  alias view='vim -R'
fi

HISTSIZE=1000
if [[ -n "${zsh_writable:-}" ]]; then
  HISTSIZE=2000 SAVEHIST=1000 HISTFILE="${zsh_writable}history.zsh"
fi

# Some systems export HOST by default, but if we then jexec into a jail, our
# prompt gets confused and persists the original.  If we're not zsh before
# jexec, then this won't help, but if we are, it should.
typeset +x HOST

# Non-path environ tuning }}}

# Prompt {{{

#promptinit
#prompt pdp
#PS1='%?:%n@%1m:%~%# '
(){
autoload -U colors ; [[ ${(t)fg} != association* ]] && colors
local ul="%{"$'\e['"$color[underline]m%}"
local rs="%{$reset_color%}"
local cerr="%{$fg_bold[red]%}"
local cuser="%{$fg[green]%}"
local cuser_root="%{$fg[green]${bg[red]}%}"
local chost="%{$fg[yellow]%}"
local cjobs="%{$bold_color%}"
local cdirs="%{$fg_bold[green]%}"
local m_username='%n'
[[ -z "${USERNAME:-}" ]] && m_username="[$UID/$EUID]"
local muser="%(#.${cuser_root}.${cuser})${m_username}${rs}"
local mjail=''
[[ -n ${IS_CONTAINER:-} ]] && mjail="%{$fg_bold[magenta]%}*${rs}"
#
function prompt_pdp_precmd {
  local ex=$?;
  psvar=( $ex )
  if [[ $ex -ge 128 ]]; then
    psvar[1]=SIG${signals[$ex-127]:-} ; [[ $psvar[1] == SIG ]] && psvar[1]=$ex
  elif [[ $ex -eq 127 ]]; then psvar[1]='127/CmdNotFound'         # SUSv4 XCU 2.8.2
  elif [[ $ex -eq 126 ]]; then psvar[1]='126/CmdNotExecutable'    # SUSv4 XCU 2.8.2
  elif [[ $ex -eq 125 ]]; then psvar[1]='125/GitBisectUntestable' # git
  fi
  psvar[2]=$#jobstates; [[ $psvar[2] -eq 0 ]] && psvar[2]=''
  psvar[3]=$#dirstack; [[ $psvar[3] -eq 0 ]] && psvar[3]=''
  return $ex
}
typeset -gu precmd_functions; precmd_functions+=( prompt_pdp_precmd )
#
local pa
pa=(
  "%2(L.${ul}[%L]${rs} .)"				# SHLVL
  "%(?.0.${cerr}%1v${rs}) "				# $? (via psvar[1] so %1v ipv %?)
  "%(2V,<${cjobs}+%2v${rs}> ,)"				# jobs
  "${muser}@${mjail}${chost}%1m${rs}"			# user@host
  "%(3V,${cdirs}(%3v)${rs},:)"				# dirstack, else :
  "%~%# "
)
local p1="${(j::)pa}"
local empty='%{%}'
PS1="${p1//$empty/}"
}

# Prompt }}}

# Completion & Keybinding {{{

bindkey -e

zstyle ':completion:*' auto-description '4 %d'
zstyle ':completion:*' completer _expand _complete
#zstyle ':completion:*' glob true
zstyle ':completion:*' group-name ''
zstyle ':completion:*' insert-unambiguous true
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or the character to insert%s'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' original true
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
zstyle ':completion:*' urls ~/.urls
zstyle ':completion:*' use-perl true
#zstyle ':completion:*:glob:*' menu false
zstyle :compinstall filename '/root/.zshrc'
# prefer "all entries" above others, so foo*<tab> gets all as first expansion
zstyle ':completion:*:expand:*' tag-order all-expansions

function backward-kill-partial-word {
  local WORDCHARS="${WORDCHARS//[\/.]/}"
  zle backward-kill-word "$@"
}
zle -N backward-kill-partial-word
for x in '^Xw' '^[^?' '^[^H'; do
        bindkey "$x" backward-kill-partial-word
done; unset x
zle -N edit-command-line
bindkey '^[v' edit-command-line
zle -N copy-earlier-word
bindkey '^[,' copy-earlier-word

# per man-page, and how to set up grabbing of results so that ^Xa inserts what we saw as possibilities
zle -C all-matches complete-word _generic
zstyle ':completion:all-matches:*' old-matches only
zstyle ':completion:all-matches::::' completer _all_matches
bindkey '^Xa' all-matches

autoload -Uz compinit
if [[ -n "${zsh_writable:-}" ]]; then
  d="${zsh_writable}zcompdumps"; [[ -d "$d" ]] || mkdir -m 0700 "$d"
  compinit -u -d "$d/${HOST%%.*}-$ZSH_VERSION"
  unset d
else
  compinit -u
fi

# Completion & Keybinding }}}

# Aliases and functions {{{

# some possibly above under environ tuning too

typeset -a _e
_e=('LC_COLLATE=C')
_o=''
if [[ $OSTYPE == (freebsd|darwin)* ]]; then
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
eval "function l { $_e ls $_o \"\$@\" }"
unset _o _e


function have_here {
  find "${@:-.}" -type d \
    \( -name .git -o -name .svn -o -name .bzr -o -name CVS -o -name .hg -o -name __pycache__ \) \
    -prune -o -type f -print
}

function rgrep {
	if [[ $OSTYPE == freebsd* && ${${OSTYPE#freebsd}%.*} -ge 10 && -x /usr/local/bin/grep ]]; then
		local PATH="/usr/local/bin:$PATH"
	fi
	local cmd=grep
	case "$1" in
		--pcre|--pcregrep)	cmd=pcregrep	; shift ;;
		--fix|--fixed|--fgrep)	cmd=fgrep	; shift ;;
		--extended|--egrep)	cmd=egrep	; shift ;;
		--grep)			cmd=grep	; shift ;;
	esac
	local -a skip_extensions
	local -a skip_dirs
	skip_dirs=( .vagrant .git .svn .bzr CVS .hg __pycache__ )
	skip_extensions=( gpg swp vmem vmdk iso )

	"$cmd" -r --exclude-dir=${^skip_dirs} --exclude='.*\.'${^skip_extensions} \
		--exclude='.*~' \
		"$@"
}

for cmd in less; do
  for dir in /opt/spodhuis/bin /usr/local/bin ; do
    test -x "$dir/$cmd" || continue
    alias "$cmd=$dir/$cmd"
    break
  done
done

# Aliases and functions }}}

# Per-vhost/jail/container settings {{{
# Omitted for Docker container
# Per-vhost/jail/container settings }}}

# vim: set foldmethod=marker sw=2 :
# EOF
