#!/usr/bin/env bash

if [[ -z "${DEVSTACK_WORKSPACE}" ]]; then
  echo "DEVSTACK_WORKSPACE environment variable undefined. Exiting..."
  exit 1
fi

cd $DEVSTACK_WORKSPACE/enterprise-catalog/ && make dev.down
cd ../license-manager/ && make dev.down
cd ../devstack/ && make dev.down

MFE_PORTS=(
  "8734"
  "1991"
)
for port in ${MFE_PORTS[*]}; do
  echo "Killing MFE listening on port ${port}"
  kill $(lsof -i tcp:$port | grep LISTEN | awk '{print $2}')
done

exit 0

