#!/bin/bash
set -euxo pipefail

# install dependencies.
apt-get install -y python3-dotenv

# download.
# see https://github.com/containers/podman-compose/releases
# renovate: datasource=github-releases depName=containers/podman-compose
podman_compose_version='1.5.0'
podman_compose_url="https://raw.githubusercontent.com/containers/podman-compose/refs/tags/v$podman_compose_version/podman_compose.py"
wget -qO /tmp/podman-compose "$podman_compose_url"

# install.
install -m 555 /tmp/podman-compose /usr/local/bin
rm /tmp/podman-compose
podman compose version
