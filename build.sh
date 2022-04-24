#!/usr/bin/env bash
set -euo pipefail

export DOCKER_DEFAULT_PLATFORM=linux/amd64
export DOCKER_BUILDKIT=1

remote_origin_url=$(git config --get remote.origin.url)
remote_origin_path=${remote_origin_url#*:}
remote_origin_path_without_extension=${remote_origin_path%.*}

export GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-$remote_origin_path_without_extension}
export GITHUB_SHA=${GITHUB_SHA:-$(git rev-parse HEAD)}

echo "GITHUB_REPOSITORY=$GITHUB_REPOSITORY"
echo "GITHUB_SHA=$GITHUB_SHA"

docker-compose build
docker-compose push