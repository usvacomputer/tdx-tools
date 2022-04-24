#!/usr/bin/env bash
set -euo pipefail

_shutdown() {
  echo ""
  echo "SHUTDOWN"

  docker-compose down --timeout 0

  exit 0
}

trap _shutdown INT TERM ERR
export DOCKER_DEFAULT_PLATFORM=linux/amd64

# otherwise multiple networks with the same name will appear when docker-compose is launched in parallel
docker network create tdx-tools_default || true

(
  export INPUT_PACKAGE=""
  docker-compose --ansi never build centos-stream-8-pkg-builder
)

if [ "${1:-}" = "" ]; then
  packages="intel-mvp-spr-qemu-kvm intel-mvp-tdx-libvirt intel-mvp-spr-kernel intel-mvp-tdx-tdvf intel-mvp-tdx-guest-grub2 intel-mvp-tdx-guest-shim"
else
  packages=$@
fi

declare -A pids
for package in $packages; do
  (
    export INPUT_PACKAGE=$package
    docker-compose --ansi never run centos-stream-8-pkg-builder | tee "/tmp/$package.log"
    touch build/centos-stream-8/$package/build.done
  ) 2>&1 | sed -le "s#\x1B\[[0-9;]\{1,\}[A-Za-z]##g;s#^#$package: #;" &
  pids[$package]=$!
done

declare -A statuses
for package in "${!pids[@]}"; do
  pid=${pids[$package]}
  set +e
    wait $pid
    code=$?
  set -e
  if [ "$code" = "0" ]; then
    statuses[$package]=ok
  else
    statuses[$package]=fail
  fi
done

failed=no
for package in "${!statuses[@]}"; do
  status=${statuses[$package]}
  echo "$package logs in /tmp/$package.log: $status"
  if [ "$status" = "fail" ]; then
    failed=yes
  fi
done

echo ""
if [ "$failed" = "yes" ]; then
  echo "FAIL"
else
  echo "OK"
fi
