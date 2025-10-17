#!/bin/bash
set -eux

# install podman and the docker like alias.
# NB ubuntu noble 24.04 ships with podman 4.9.3.
# see https://packages.ubuntu.com/noble/podman
apt-get install -y \
    podman
apt-get install -y --no-install-recommends \
    podman-docker

# prevent the emulated docker cli warning message.
# NB this prevents the message:
#       Emulate Docker CLI using podman. Create /etc/containers/nodocker to quiet msg.
touch /etc/containers/nodocker

# configure podman.
# NB --userns=keep-id is required to be able to write into the job working
#    directory when using the jenkins docker workflow plugin.
# NB compose_warning_logs prevents the warning:
#       >>>> Executing external compose provider "/usr/bin/podman-compose". Please refer to the documentation for details. <<<<
# NB these settings could also be in ~/.config/containers/containers.conf.
# see https://github.com/containers/common/blob/main/docs/containers.conf.5.md
cat >/etc/containers/containers.conf<<'EOF'
[containers]
userns = "keep-id"
log_driver = "k8s-file"

[engine]
compose_warning_logs = false
compose_providers = ["/usr/local/bin/podman-compose"]
EOF

# configure the jenkins user namespace mapping.
# NB the vagrant user uses 100000-65536. jenkins will use the next block.
usermod --add-subuids 165536-231071 --add-subgids 165536-231071 jenkins

# kick the tires.
podman version
podman info
podman network ls
ip link
bridge link
#podman run --rm hello-world
#podman run --rm alpine:3.22 cat /etc/os-release
#podman run --rm debian:13-slim cat /etc/os-release
#podman run --rm ubuntu:24.04 cat /etc/os-release
