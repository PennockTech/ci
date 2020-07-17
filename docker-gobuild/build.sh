#!/usr/bin/env bash
set -euo pipefail

progname="$(basename "$0" .sh)"
warn() { printf >&2 '%s: %s\n' "$progname" "$*"; }
die() { warn "$@"; exit 1; }

for nf in docker-gobuild/build.sh docker-gobuild/Dockerfile; do
  test -f "$nf" || die "missing file $nf"
done

build=(
  --build-arg REPO_STATE="$(git describe --tags --always --dirty)"
  -f docker-gobuild/Dockerfile
  )

[[ -n "${1:-}" ]] || die "need a go version so we can get the tag cleanly"

case "${1:?}" in
  [12].*) true ;;
  *) die "need a Go version" ;;
esac
GO_V="$1"
shift
build+=( --build-arg GOLANG_VERSION="$GO_V" )

IMG="pennocktech/ci:gobuild-$GO_V"

docker build "${build[@]}" -t "${IMG}-root" --target=rootstage .
docker build "${build[@]}" -t "$IMG" .

# vim: set sw=2 et :
