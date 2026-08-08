#!/usr/bin/env bash

set -euo pipefail

if [[ ! -f .env ]]; then
	echo "Missing .env file. Copy .env.example to .env and configure it first."
	exit 1
fi

set -a
source .env
set +a

container_database_url="${DATABASE_URL/localhost/host.docker.internal}"

docker run --rm --init \
	--name supportdesk-app \
	--add-host host.docker.internal:host-gateway \
	--env BETTER_AUTH_GITHUB_CLIENT_ID \
	--env BETTER_AUTH_GITHUB_CLIENT_SECRET \
	--env BETTER_AUTH_SECRET \
	--env BETTER_AUTH_URL \
	--env DATABASE_URL="$container_database_url" \
	--publish 3000:3000 \
	supportdesk:local
