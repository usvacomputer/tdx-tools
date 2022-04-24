#!/usr/bin/env bash
set -euo pipefail

export DOCKER_DEFAULT_PLATFORM=linux/amd64

# otherwise multiple networks with the same name will appear when docker-compose is launched in parallel
docker network create tdx-tools_default || true

docker-compose --ansi never build centos-stream-8-pkg-builder

if [ "${1:-}" = "" ]; then
  services=$(docker-compose --ansi never config --services)
else
  services=$@
fi

declare -A pids
for service in $services; do
  [ "$service" = "centos-stream-8-pkg-builder" ] && continue

  (
    exec docker-compose --ansi never run $service | tee "/tmp/$service.log"
  ) 2>&1 | sed -le 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g' | sed -le "s#^#$service: #;" &
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
  echo "$service logs in /tmp/$service.log: $status"
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
