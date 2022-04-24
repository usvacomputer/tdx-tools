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

(
  export GITHUB_SHA=cache
  docker-compose pull --ignore-pull-failures centos-stream-8-pkg-builder || true
)
docker-compose build centos-stream-8-pkg-builder

# (
#   docker tag ghcr.io/${GITHUB_REPOSITORY}/centos-stream-8-pkg-builder:${GITHUB_SHA} ghcr.io/${GITHUB_REPOSITORY}/centos-stream-8-pkg-builder:cache
#   docker push ghcr.io/${GITHUB_REPOSITORY}/centos-stream-8-pkg-builder:cache
# )

if [ "${1:-}" = "" ]; then
  services=$(docker-compose config --services)
else
  services=$@
fi

for service in $services; do
  [ "$service" = "centos-stream-8-pkg-builder" ] && continue

  (
    docker-compose build $service
    #docker-compose push $service
  ) 2>&1 | sed -le "s#^#$service: #;" &
done

wait
echo ""
echo "DONE"