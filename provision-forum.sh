#!/usr/bin/env bash
set -eu -o pipefail
set -x

name=forum

docker compose up -d ${name}
docker compose exec -T ${name} bash -e -c 'cd /edx/app/forum/cs_comments_service && make initialize_search' -- "$name"
