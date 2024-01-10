#!/usr/bin/env bash

if [[ -z "${DEVSTACK_WORKSPACE}" ]]; then
  echo "DEVSTACK_WORKSPACE environment variable undefined. Exiting..."
  exit 1
fi

cd $DEVSTACK_WORKSPACE/devstack/ && make dev.up.lms+ecommerce
cd ../enterprise-catalog/ && make dev.up
cd ../license-manager/ && make dev.up

if [[ $(lsof -i tcp:8734 | grep LISTEN | awk '{print $2}') ]]
then
  echo "INFO: Enterprise Learner Portal already running"
else
  echo "INFO: Starting Enterprise Learner Portal"
  cd ../frontend-app-learner-portal-enterprise/ && npm start &
fi

if [[ $(lsof -i tcp:1991 | grep LISTEN | awk '{print $2}') ]]
then
  echo "INFO: Enterprise Admin Portal already running"
else
  echo "INFO: Starting Enterprise Admin Portal"
  cd ../frontend-app-admin-portal/ && npm start &
fi

exit 0

