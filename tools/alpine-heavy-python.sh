#!/bin/sh -eu

# These should be supplied by Docker
: "${PT_VARIANT:?}" # purple

# shellcheck source=tools/lib.sh disable=SC2034
. "$(dirname "$0")/lib.sh" "$0" "$@"
startdir=/tmp
cd "$startdir"

if have_cmd pip; then
  pip install --upgrade pip setuptools
else
  warn "missing pip"
fi
if have_cmd pip3; then
  pip3 install --upgrade pip setuptools
  pip3 install -r "etc/py-requirements-${PT_VARIANT:?}.txt"
else
  warn "missing pip3, skipped python packages"
fi
