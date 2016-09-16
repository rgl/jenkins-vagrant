#!/bin/bash
set -eux

domain=$(hostname --fqdn)

echo 'Defaults env_keep += "DEBIAN_FRONTEND"' >/etc/sudoers.d/env_keep_apt
chmod 440 /etc/sudoers.d/env_keep_apt
export DEBIAN_FRONTEND=noninteractive


#
# install vim.

apt-get install -y --no-install-recommends vim

cat >~/.vimrc <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF


#
# configure the shell.

cat >~/.bash_history <<'EOF'
systemctl status nginx
systemctl restart nginx
systemctl status jenkins
systemctl restart jenkins
less /var/log/jenkins/jenkins.log
tail -f /var/log/jenkins/jenkins.log
tail -f /var/log/jenkins/access.log | grep -v ajax
cat /var/lib/jenkins/secrets/initialAdminPassword 
cd /var/lib/jenkins
netstat -antp
jcli version
EOF

cat >~/.bashrc <<'EOF'
# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

export EDITOR=vim
export PAGER=less

alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
alias jcli='java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080 -i ~/.ssh/id_rsa'
alias jgroovy='jcli groovy'
EOF

cat >~/.inputrc <<'EOF'
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
set show-all-if-ambiguous on
set completion-ignore-case on
EOF


#
# create a self-signed certificate.

pushd /etc/ssl/private
openssl genrsa \
    -out $domain-keypair.pem \
    2048 \
    2>/dev/null
chmod 400 $domain-keypair.pem
openssl req -new \
    -sha256 \
    -subj "/CN=$domain" \
    -key $domain-keypair.pem \
    -out $domain-csr.pem
openssl x509 -req -sha256 \
    -signkey $domain-keypair.pem \
    -extensions a \
    -extfile <(echo "[a]
        subjectAltName=DNS:$domain
        extendedKeyUsage=serverAuth
        ") \
    -days 365 \
    -in  $domain-csr.pem \
    -out $domain-crt.pem
popd


#
# install nginx as a proxy to Jenkins.

apt-get install -y --no-install-recommends nginx
cat >/etc/nginx/sites-available/jenkins <<EOF
ssl_session_cache shared:SSL:4m;
ssl_session_timeout 6h;
#ssl_stapling on;
#ssl_stapling_verify on;
server {
    listen 80;
    server_name _;
    return 301 https://$domain\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name $domain;
    client_max_body_size 50m;

    ssl_certificate /etc/ssl/private/$domain-crt.pem;
    ssl_certificate_key /etc/ssl/private/$domain-keypair.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    # see https://github.com/cloudflare/sslconfig/blob/master/conf
    # see https://blog.cloudflare.com/it-takes-two-to-chacha-poly/
    # see https://blog.cloudflare.com/do-the-chacha-better-mobile-performance-with-cryptography/
    # NB even though we have CHACHA20 here, the OpenSSL library that ships with Ubuntu 16.04 does not have it. so this is a nop. no problema.
    ssl_ciphers EECDH+CHACHA20:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!aNULL:!MD5;
    add_header Strict-Transport-Security "max-age=31536000; includeSubdomains";

    access_log /var/log/nginx/$domain-access.log;
    error_log /var/log/nginx/$domain-error.log;

    # uncomment the following to debug errors and rewrites.
    #error_log /var/log/nginx/$domain-error.log debug;
    #rewrite_log on;

    location ~ "(/\\.|/\\w+-INF|\\.class\$)" {
        return 404;
    }

    location ~ "^/static/[0-9a-f]{8}/plugin/(.+/.+)" {
        alias /var/lib/jenkins/plugins/\$1;
    }

    location ~ "^/static/[0-9a-f]{8}/(.+)" {
        rewrite "^/static/[0-9a-f]{8}/(.+)" /\$1 last;
    }

    location /userContent/ {
        root /var/lib/jenkins;
    }

    location / {
        root /var/cache/jenkins/war;
        try_files \$uri @jenkins;
    }

    location @jenkins {
        proxy_pass http://127.0.0.1:8080;
        proxy_redirect default;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
rm /etc/nginx/sites-enabled/default
ln -s ../sites-available/jenkins /etc/nginx/sites-enabled/jenkins
systemctl restart nginx


#
# install Jenkins.

wget -qO- https://pkg.jenkins.io/debian-stable/jenkins.io.key | apt-key add -
echo 'deb http://pkg.jenkins.io/debian-stable binary/' >/etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y --no-install-recommends jenkins
bash -c 'while [ ! -s /var/lib/jenkins/secrets/initialAdminPassword ]; do sleep 1; done'
systemctl stop jenkins
apt-get install -y xmlstarlet
chmod 751 /var/cache/jenkins
pushd /var/lib/jenkins
# disable security.
# see https://wiki.jenkins-ci.org/display/JENKINS/Disable+security
xmlstarlet edit --inplace -u '/hudson/useSecurity' -v 'false' config.xml
xmlstarlet edit --inplace -d '/hudson/authorizationStrategy' config.xml
xmlstarlet edit --inplace -d '/hudson/securityRealm' config.xml
# enable CLI/JNLP.
xmlstarlet edit --inplace -u '/hudson/slaveAgentPort' -v '9090' config.xml
# bind to localhost.
sed -i -E 's,^(JENKINS_ARGS="-.+),\1\nJENKINS_ARGS="$JENKINS_ARGS --httpListenAddress=127.0.0.1",' /etc/default/jenkins
# configure access log.
# NB this is useful for testing whether static files are really being handled by nginx.
sed -i -E 's,^(JENKINS_ARGS="-.+),\1\nJENKINS_ARGS="$JENKINS_ARGS --accessLoggerClassName=winstone.accesslog.SimpleAccessLogger --simpleAccessLogger.format=combined --simpleAccessLogger.file=/var/log/jenkins/access.log",' /etc/default/jenkins
sed -i -E 's,^(/var/log/jenkins/)jenkins.log,\1*.log,' /etc/logrotate.d/jenkins
# disable showing the wizard on the first access.
cp -p jenkins.install.UpgradeWizard.state jenkins.install.InstallUtil.lastExecVersion
popd
systemctl start jenkins
bash -c 'while ! wget -q --spider http://localhost:8080/cli; do sleep 1; done;'


#
# configure Jenkins.

JCLI="java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080"

function jcli {
    $JCLI -noKeyAuth "$@"
}

function jgroovy {
    jcli groovy "$@"
}

# customize.
# see http://javadoc.jenkins-ci.org/jenkins/model/Jenkins.html
jgroovy = <<'EOF'
import jenkins.model.Jenkins

Jenkins.instance.noUsageStatistics = true
Jenkins.instance.numExecutors = 3
Jenkins.instance.labelString = "hello-world test"
Jenkins.instance.save()
EOF

# install git and the git plugin.
apt-get install -y git-core
su jenkins -c bash <<'EOF'
set -eux
git config --global user.email 'jenkins@example.com'
git config --global user.name 'Jenkins'
git config --global push.default simple
git config --global core.autocrlf false
EOF
jcli install-plugin git -deploy


#
# configure security.

# generate a default SSH key-pair for use in the Jenkins CLI authentication.
ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa

# set the admin SSH public key.
# see http://javadoc.jenkins-ci.org/hudson/model/User.html
# see https://github.com/jenkinsci/ssh-cli-auth-module/blob/master/src/main/java/org/jenkinsci/main/modules/cli/auth/ssh/UserPropertyImpl.java
jgroovy = "$(cat ~/.ssh/id_rsa.pub)" <<'EOF'
import hudson.model.User
import org.jenkinsci.main.modules.cli.auth.ssh.UserPropertyImpl

u = User.getById("admin", false)
u.addProperty(new UserPropertyImpl(args[0]+"\n"))
u.save()
EOF

# enable simple security.
# see http://javadoc.jenkins-ci.org/hudson/security/HudsonPrivateSecurityRealm.html
jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy

Jenkins.instance.securityRealm = new HudsonPrivateSecurityRealm(false)

Jenkins.instance.authorizationStrategy = new FullControlOnceLoggedInAuthorizationStrategy(
  allowAnonymousRead: true)

Jenkins.instance.save()
EOF

# redefine jcli to use SSH authentication.
function jcli {
    $JCLI -i ~/.ssh/id_rsa "$@"
}

# create example accounts.
# see http://javadoc.jenkins-ci.org/hudson/model/User.html
# see http://javadoc.jenkins-ci.org/hudson/security/HudsonPrivateSecurityRealm.html
# see https://github.com/jenkinsci/mailer-plugin/blob/master/src/main/java/hudson/tasks/Mailer.java
jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.tasks.Mailer

[
    [id: "alice.doe",   fullName: "Alice Doe"],
    [id: "bob.doe",     fullName: "Bob Doe"  ],
    [id: "carol.doe",   fullName: "Carol Doe"],
    [id: "dave.doe",    fullName: "Dave Doe" ],
    [id: "eve.doe",     fullName: "Eve Doe"  ],
    [id: "frank.doe",   fullName: "Frank Doe"],
    [id: "grace.doe",   fullName: "Grace Doe"],
    [id: "henry.doe",   fullName: "Henry Doe"],
].each {
    u = Jenkins.instance.securityRealm.createAccount(it.id, "password")
    u.fullName = it.fullName
    u.addProperty(new Mailer.UserProperty(it.id+"@example.com"))
    u.save()
}
EOF


#
# show install summary.

systemctl status jenkins
jcli version
jcli list-plugins | sort
jgroovy = <<'EOF'
import hudson.model.User
import jenkins.model.Jenkins

Jenkins.instance.assignedLabels.sort().each { println "jenkins label: " + it }
User.all.sort { it.id }.each { println sprintf("jenkins user: %s (%s)", it.id, it.fullName) }
EOF
echo "jenkins is installed at https://jenkins.example.com"
echo "the admin password is $(cat /var/lib/jenkins/secrets/initialAdminPassword)"
