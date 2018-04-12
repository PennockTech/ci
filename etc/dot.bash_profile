# ~/.bash_profile

[[ -n "${INHERIT_ENV:-}" ]] && return 0

# Get `path_arr` as elements of $PATH
oIFS="$IFS" ; IFS=":"
read -a path_arr <<<"$PATH"
IFS="$oIFS"; unset oIFS

have_cmd() {
  local c="$1"
  for p in "${path_arr[@]}"; do
    [[ -x "$p/$c" ]] && return 0
  done
  return 1
}

have_cmd zsh && alias z='exec zsh -l'


: "${USER:=$(id -un)}"
: "${HOME:=/home/${USER}}"

if [[ -r "${HOME}/.bashrc" ]]; then
  source "${HOME}/.bashrc" || true
fi

unset -v path_arr
unset -f have_cmd

# vim: set ft=sh sw=2 et :
