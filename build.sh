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

if ! >/dev/null docker image inspect ghcr.io/${GITHUB_REPOSITORY}/centos-stream-8-pkg-builder:${GITHUB_SHA}; then
  (
    export GITHUB_SHA=cache
    docker-compose pull --ignore-pull-failures centos-stream-8-pkg-builder || true
  )
  docker-compose build centos-stream-8-pkg-builder

  (
    docker tag ghcr.io/${GITHUB_REPOSITORY}/centos-stream-8-pkg-builder:${GITHUB_SHA} ghcr.io/${GITHUB_REPOSITORY}/centos-stream-8-pkg-builder:cache
    docker push ghcr.io/${GITHUB_REPOSITORY}/centos-stream-8-pkg-builder:cache
  )
fi

if [ "${1:-}" = "" ]; then
  services=$(docker-compose config --services)
else
  services=$@
fi

declare -A pids
for service in $services; do
  [ "$service" = "centos-stream-8-pkg-builder" ] && continue

  (
    exec docker-compose run $service | tee "/tmp/$service.log"
  ) 2>&1 | sed -le "s#^#$service: #;" &
  pids[$service]=$!
done

declare -A statuses
for service in "${!pids[@]}"; do
  pid=${pids[$service]}
  set +e
    wait $pid
    code=$?
  set -e
  if [ "$code" = "0" ]; then
    statuses[$service]=ok
  else
    statuses[$service]=fail
  fi
done

failed=no
for service in "${!statuses[@]}"; do
  status=${statuses[$service]}
  echo "$service logs in /tmp/$service.log: $status "
  if [ "$status" = "fail" ]; then
    failed=yes
    cat /tmp/$service.log
  fi
done

echo ""
if [ "$failed" = "yes" ]; then
  echo "FAIL"
else
  echo "OK"
fi
