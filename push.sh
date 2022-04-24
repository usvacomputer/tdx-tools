#!/usr/bin/env bash
set -euo pipefail

_err() {
  echo "err: $@"
  exit 1
}

export DOCKER_DEFAULT_PLATFORM=linux/amd64
export DOCKER_BUILDKIT=1

remote_origin_url=$(git config --get remote.origin.url)
case $remote_origin_url in
  git@github.com:*)
    remote_origin_path=${remote_origin_url#*:}
    remote_origin_path=${remote_origin_path%.*} # remove .git
  ;;
  https://github.com/*)
    remote_origin_path=$(echo $remote_origin_url | cut -d/ -f 4-)
  ;;
  *)
    _err "unknown remote origin url"
  ;;
esac

export GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-$remote_origin_path}
export GITHUB_SHA=${GITHUB_SHA:-$(git rev-parse HEAD)}

echo "GITHUB_REPOSITORY=$GITHUB_REPOSITORY"
echo "GITHUB_SHA=$GITHUB_SHA"

