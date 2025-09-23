#!/bin/bash
set -eux

# download and install.
# renovate: datasource=github-releases depName=axllent/mailpit
artifact_version='1.27.8'
artifact_url=https://github.com/axllent/mailpit/releases/download/v$artifact_version/mailpit-linux-amd64.tar.gz
t="$(mktemp -q -d --suffix=.mailpit)"
wget -qO- "$artifact_url" | tar xzf - -C "$t"
install -d /opt/mailpit/bin
install -m 555 "$t/mailpit" /opt/mailpit/bin/mailpit
/opt/mailpit/bin/mailpit version
rm -rf "$t"

# create the service and start it.
groupadd --system mailpit
adduser \
    --system \
    --disabled-login \
    --no-create-home \
    --gecos '' \
    --ingroup mailpit \
    --home /opt/mailpit \
    --shell /bin/bash \
    mailpit
install -d -o mailpit -g mailpit -m 750 /opt/mailpit
install -d -o mailpit -g mailpit -m 750 /opt/mailpit/data
cat >/etc/systemd/system/mailpit.service <<'EOF'
[Unit]
Description=mailpit
After=network.target

[Service]
Type=simple
User=mailpit
Group=mailpit
ExecStart=/opt/mailpit/bin/mailpit \
    --disable-version-check \
    --db-file /opt/mailpit/data/mailpit.db \
    --smtp-auth-accept-any \
    --smtp-auth-allow-insecure
WorkingDirectory=/opt/mailpit
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable mailpit
systemctl start mailpit

# configure the system to use mailpit as a smarthost.
# these answers were obtained (after installing nullmailer) with:
#   #sudo debconf-show nullmailer
#   sudo apt-get install debconf-utils
#   # this way you can see the comments:
#   sudo debconf-get-selections
#   # this way you can just see the values needed for debconf-set-selections:
#   sudo debconf-get-selections | grep -E '^nullmailer\s+' | sort
debconf-set-selections <<EOF
nullmailer nullmailer/defaultdomain string `hostname --domain`
nullmailer nullmailer/relayhost string localhost smtp --port=1025
nullmailer shared/mailname string `hostname --fqdn`
EOF
apt-get install -y nullmailer

# send test email.
sendmail root <<EOF
Subject: Test Email from `hostname --fqdn` at `date --iso-8601=seconds`

Sent from $0:$LINENO
EOF
