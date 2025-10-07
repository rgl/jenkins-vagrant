#!/bin/bash
set -euxo pipefail

# download.
# see https://docs.docker.com/compose/install/#install-compose-on-linux-systems
# see https://github.com/docker/compose/releases
# renovate: datasource=github-releases depName=docker/compose
docker_compose_version='2.40.0'
docker_compose_url="https://github.com/docker/compose/releases/download/v$docker_compose_version/docker-compose-linux-$(uname -m)"
wget -qO /tmp/docker-compose "$docker_compose_url"

# install.
install -d /usr/local/lib/docker/cli-plugins
install -m 555 /tmp/docker-compose /usr/local/lib/docker/cli-plugins
rm /tmp/docker-compose
docker compose version
