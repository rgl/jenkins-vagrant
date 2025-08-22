#!/bin/bash
set -eux

domain=$(hostname --fqdn)

# see https://www.jenkins.io/download/
jenkins_version='2.319.3'

# use the local Jenkins user database.
config_authentication='jenkins'
# OR use LDAP.
# NB this assumes you are running the Active Directory from https://github.com/rgl/windows-domain-controller-vagrant.
# NB AND you must manually copy its tmp/ExampleEnterpriseRootCA.der file to this environment tmp/ directory.
#config_authentication='ldap'


echo 'Defaults env_keep += "DEBIAN_FRONTEND"' >/etc/sudoers.d/env_keep_apt
chmod 440 /etc/sudoers.d/env_keep_apt
export DEBIAN_FRONTEND=noninteractive


#
# make sure the package index cache is up-to-date before installing anything.

apt-get update


#
# install a EGD (Entropy Gathering Daemon).
# NB the host should have an EGD and expose/virtualize it to the guest.
#    on libvirt there's virtio-rng which will read from the host /dev/random device
#    so your host should have a TRNG (True RaNdom Generator) with rng-tools
#    reading from it and feeding it into /dev/random or have the haveged
#    daemon running.
# see https://wiki.qemu.org/Features/VirtIORNG
# see https://wiki.archlinux.org/index.php/Rng-tools
# see https://www.kernel.org/doc/Documentation/hw_random.txt
# see https://hackaday.com/2017/11/02/what-is-entropy-and-how-do-i-get-more-of-it/
# see cat /sys/devices/virtual/misc/hw_random/rng_current
# see cat /proc/sys/kernel/random/entropy_avail
# see rngtest -c 1000 </dev/hwrng
# see rngtest -c 1000 </dev/random
# see rngtest -c 1000 </dev/urandom
apt-get install -y rng-tools


#
# enable systemd-journald persistent logs.

sed -i -E 's,^#?(Storage=).*,\1persistent,' /etc/systemd/journald.conf
systemctl restart systemd-journald


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
sudo -sHu jenkins
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
alias jcli="java -jar /var/cache/jenkins/war/WEB-INF/lib/cli-*.jar -s http://localhost:8080 -http -auth @$HOME/.jenkins-cli"
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
# trust the gitlab-vagrant environment certificate.

if [ -f /vagrant/tmp/gitlab.example.com-crt.der ]; then
    openssl x509 \
        -inform der \
        -in /vagrant/tmp/gitlab.example.com-crt.der \
        -out /usr/local/share/ca-certificates/gitlab.example.com.crt
    update-ca-certificates
fi


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
# install dependencies.

apt-get install -y openjdk-11-jre-headless
apt-get install -y gnupg
apt-get install -y xmlstarlet


#
# fix "java.lang.NoClassDefFoundError: Could not initialize class org.jfree.chart.JFreeChart"
# error while rendering the xUnit Test Result Trend chart on the job page.

sed -i -E 's,^(\s*assistive_technologies\s*=.*),#\1,' /etc/java-11-openjdk/accessibility.properties 


#
# install Jenkins.
# see https://pkg.jenkins.io/debian/

wget -qO- https://pkg.jenkins.io/debian-stable/jenkins.io.key | apt-key add -
echo 'deb http://pkg.jenkins.io/debian-stable binary/' >/etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y --no-install-recommends "jenkins=$jenkins_version"
pushd /var/lib/jenkins
# wait for initialization to finish.
bash -c 'while [ ! -f "/var/lib/jenkins/secrets/initialAdminPassword" ]; do sleep 1; done'
systemctl stop jenkins
chmod 751 /var/cache/jenkins
mv config.xml{,.orig}
# remove the xml 1.1 declaration because xmlstarlet does not support it... and xml 1.1 is not really needed.
tail -n +2 config.xml.orig >config.xml
# disable security.
# see https://wiki.jenkins-ci.org/display/JENKINS/Disable+security
xmlstarlet edit --inplace -u '/hudson/useSecurity' -v 'false' config.xml
xmlstarlet edit --inplace -d '/hudson/authorizationStrategy' config.xml
xmlstarlet edit --inplace -d '/hudson/securityRealm' config.xml
# disable the install wizard.
sed -i -E 's,^(JAVA_ARGS="-.+),\1\nJAVA_ARGS="$JAVA_ARGS -Djenkins.install.runSetupWizard=false",' /etc/default/jenkins
# modify the slave workspace directory name to be just "w" as a way to minimize
# path-too-long errors on windows slaves.
# NB unfortunately this setting applies to all slaves.
# NB in a pipeline job you can also use the customWorkspace option.
# see windows/provision-jenkins-slaves.ps1.
# see https://issues.jenkins-ci.org/browse/JENKINS-12667
# see https://wiki.jenkins.io/display/JENKINS/Features+controlled+by+system+properties
# see https://github.com/jenkinsci/jenkins/blob/jenkins-2.319.3/core/src/main/java/hudson/model/Slave.java#L737-L740
sed -i -E 's,^(JAVA_ARGS="-.+),\1\nJAVA_ARGS="$JAVA_ARGS -Dhudson.model.Slave.workspaceRoot=w",' /etc/default/jenkins
# bind to localhost.
sed -i -E 's,^(JENKINS_ARGS="-.+),\1\nJENKINS_ARGS="$JENKINS_ARGS --httpListenAddress=127.0.0.1",' /etc/default/jenkins
# configure access log.
# NB this is useful for testing whether static files are really being handled by nginx.
sed -i -E 's,^(JENKINS_ARGS="-.+),\1\nJENKINS_ARGS="$JENKINS_ARGS --accessLoggerClassName=winstone.accesslog.SimpleAccessLogger --simpleAccessLogger.format=combined --simpleAccessLogger.file=/var/log/jenkins/access.log",' /etc/default/jenkins
sed -i -E 's,^(/var/log/jenkins/)jenkins.log,\1*.log,' /etc/logrotate.d/jenkins
# show the configuration changes.
diff -u config.xml{.orig,} || true
popd
systemctl start jenkins


#
# configure Jenkins.

# import the cli and redefine jcli for not using any authentication while we configure jenkins.
source /vagrant/jenkins-cli.sh
function jcli {
    $JCLI "$@"
}

# wait for the cli endpoint to be available.
jcliwait

# customize.
# see http://javadoc.jenkins-ci.org/jenkins/model/Jenkins.html
jgroovy = <<'EOF'
import hudson.model.Node.Mode
import jenkins.model.Jenkins

// disable usage statistics.
Jenkins.instance.noUsageStatistics = true

// do not run jobs on the master.
Jenkins.instance.numExecutors = 0
Jenkins.instance.mode = Mode.EXCLUSIVE

Jenkins.instance.save()
EOF

# set the jenkins url and administrator email.
# see http://javadoc.jenkins-ci.org/jenkins/model/JenkinsLocationConfiguration.html
jgroovy = <<EOF
import jenkins.model.JenkinsLocationConfiguration

c = JenkinsLocationConfiguration.get()
c.url = 'https://$domain'
c.adminAddress = 'Jenkins <jenkins@example.com>'
c.save()
EOF

# install and configure git.
apt-get install -y git-core
su jenkins -c bash <<'EOF'
set -eux
git config --global user.email 'jenkins@example.com'
git config --global user.name 'Jenkins'
git config --global push.default simple
git config --global core.autocrlf false
EOF

# install plugins.
# NB installing plugins is quite flaky, mainly because Jenkins (as-of 2.19.2)
#    does not retry their downloads. this will workaround it by (re)installing
#    until it works.
# see http://javadoc.jenkins-ci.org/jenkins/model/Jenkins.html
# see http://javadoc.jenkins-ci.org/hudson/PluginManager.html
# see http://javadoc.jenkins.io/hudson/model/UpdateCenter.html
# see http://javadoc.jenkins.io/hudson/model/UpdateSite.Plugin.html
jgroovy = <<'EOF'
import jenkins.model.Jenkins
Jenkins.instance.updateCenter.updateAllSites()
EOF
function install-plugins {
jgroovy = <<'EOF'
import jenkins.model.Jenkins

updateCenter = Jenkins.instance.updateCenter
pluginManager = Jenkins.instance.pluginManager

installed = [] as Set

def install(id) {
  plugin = updateCenter.getPlugin(id)

  plugin.dependencies.each {
    install(it.key)
  }

  if (!pluginManager.getPlugin(id) && !installed.contains(id)) {
    println("installing plugin ${id}...")
    pluginManager.install([id], false).each { it.get() }
    installed.add(id)
  }
}

[
    'cloudbees-folder',
    'email-ext',
    'gitlab-plugin',
    'git',
    'powershell',
    'xcode-plugin',
    'xunit',
    'conditional-buildstep',
    'workflow-aggregator', // aka Pipeline; see https://plugins.jenkins.io/workflow-aggregator
    'ws-cleanup', // aka Workspace Cleanup; see https://plugins.jenkins.io/ws-cleanup
].each {
  install(it)
}
EOF
}
while [[ -n "$(install-plugins)" ]]; do
    systemctl restart jenkins
    jcliwait
done

# use the local SMTP MailHog server.
jgroovy = <<'EOF'
import jenkins.model.Jenkins

c = Jenkins.instance.getDescriptor('hudson.tasks.Mailer')
c.smtpHost = 'localhost'
c.smtpPort = '1025'
c.save()
EOF

# configure the default pipeline durability setting as performance-optimized.
# see https://jenkins.io/doc/book/pipeline/scaling-pipeline/
# see https://javadoc.jenkins.io/plugin/workflow-api/org/jenkinsci/plugins/workflow/flow/GlobalDefaultFlowDurabilityLevel.DescriptorImpl.html
jgroovy = <<'EOF'
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.flow.GlobalDefaultFlowDurabilityLevel

d = Jenkins.instance.getDescriptor('org.jenkinsci.plugins.workflow.flow.GlobalDefaultFlowDurabilityLevel')
d.durabilityHint = 'PERFORMANCE_OPTIMIZED'
d.save()
EOF


#
# configure security.

# generate the SSH key-pair that jenkins master uses to communicates with the slaves.
su jenkins -c 'ssh-keygen -q -t rsa -N "" -f ~/.ssh/id_rsa'

# set the allowed agent protocols.
# NB JNLP4-connect will be used by windows nodes.
# see http://javadoc.jenkins-ci.org/jenkins/model/Jenkins.html
jgroovy = <<'EOF'
import jenkins.model.Jenkins

Jenkins.instance.agentProtocols = ["JNLP4-connect", "Ping"]
Jenkins.instance.slaveAgentPort = 50000
Jenkins.instance.save()
EOF

# enable simple security.
# also create the vagrant user account. jcli will use this account from now on.
# see http://javadoc.jenkins-ci.org/hudson/security/HudsonPrivateSecurityRealm.html
# see http://javadoc.jenkins-ci.org/hudson/model/User.html
jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy
import hudson.tasks.Mailer

Jenkins.instance.securityRealm = new HudsonPrivateSecurityRealm(false)

u = Jenkins.instance.securityRealm.createAccount('vagrant', 'vagrant')
u.fullName = 'Vagrant'
u.addProperty(new Mailer.UserProperty('vagrant@example.com'))
u.save()

Jenkins.instance.authorizationStrategy = new FullControlOnceLoggedInAuthorizationStrategy(
  allowAnonymousRead: true)

Jenkins.instance.save()
EOF

# create the vagrant user api token.
# see http://javadoc.jenkins-ci.org/hudson/model/User.html
# see http://javadoc.jenkins-ci.org/jenkins/security/ApiTokenProperty.html
# see https://jenkins.io/doc/book/managing/cli/
function jcli {
    $JCLI -http -auth vagrant:vagrant "$@"
}
jgroovy = >~/.jenkins-cli <<'EOF'
import hudson.model.User
import jenkins.security.ApiTokenProperty

u = User.current()
p = u.getProperty(ApiTokenProperty)
t = p.tokenStore.generateNewToken('vagrant')
u.save()
println sprintf("%s:%s", u.id, t.plainValue)
EOF
chmod 400 ~/.jenkins-cli

# redefine jcli to use the vagrant api token.
source /vagrant/jenkins-cli.sh

# show which user is actually being used in jcli. this should show "vagrant".
# see http://javadoc.jenkins-ci.org/hudson/model/User.html
jcli who-am-i
jgroovy = <<'EOF'
import hudson.model.User

u = User.current()
println sprintf("User id: %s", u.id)
println sprintf("User Full Name: %s", u.fullName)
u.allProperties.each { println sprintf("User property: %s", it) }; null
EOF

# use LDAP for user authentication (when enabled).
# NB this assumes you are running the Active Directory from https://github.com/rgl/windows-domain-controller-vagrant.
# see https://wiki.jenkins-ci.org/display/JENKINS/LDAP+Plugin
# see https://github.com/jenkinsci/ldap-plugin/blob/b0b86221a898ecbd95c005ceda57a67533833314/src/main/java/hudson/security/LDAPSecurityRealm.java#L480
if [ "$config_authentication" = 'ldap' ]; then
echo '192.168.56.2 dc.example.com' >>/etc/hosts
openssl x509 -inform der -in /vagrant/tmp/ExampleEnterpriseRootCA.der -out /usr/local/share/ca-certificates/ExampleEnterpriseRootCA.crt
update-ca-certificates # NB this also updates the default java key store at /etc/ssl/certs/java/cacerts.
jgroovy = <<'EOF'
import jenkins.model.Jenkins
import jenkins.security.plugins.ldap.FromUserRecordLDAPGroupMembershipStrategy
import jenkins.security.plugins.ldap.FromGroupSearchLDAPGroupMembershipStrategy
import hudson.security.LDAPSecurityRealm
import hudson.util.Secret

Jenkins.instance.securityRealm = new LDAPSecurityRealm(
    // String server:
    // TIP use the ldap: scheme and wireshark on the dc.example.com machine to troubeshoot.
    'ldaps://dc.example.com',

    // String rootDN:
    'DC=example,DC=com',

    // String userSearchBase:
    // NB this is relative to rootDN.
    'CN=Users',

    // String userSearch:
    // NB this is used to determine that a user exists.
    // NB {0} is replaced with the username.
    '(&(sAMAccountName={0})(objectClass=person)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))',

    // String groupSearchBase:
    // NB this is relative to rootDN.
    'CN=Users',

    // String groupSearchFilter:
    // NB this is used to determine that a group exists.
    // NB the search is scoped to groupSearchBase.
    // NB {0} is replaced with the groupname.
    '(&(objectCategory=group)(sAMAccountName={0}))',

    // LDAPGroupMembershipStrategy groupMembershipStrategy:
    // NB this is used to determine a user groups.
    // Default: (|(member={0})(uniqueMember={0})(memberUid={1}))
    // NB the search is scoped to groupSearchBase.
    // NB {0} is replaced with the user DN.
    // NB {1} is replaced with the username.
    new FromGroupSearchLDAPGroupMembershipStrategy('(&(objectCategory=group)(member={0}))'),
    //new FromUserRecordLDAPGroupMembershipStrategy('memberOf'),

    // String managerDN:
    'jane.doe@example.com',

    // Secret managerPasswordSecret:
    Secret.fromString('HeyH0Password'),

    // boolean inhibitInferRootDN:
    false,

    // boolean disableMailAddressResolver:
    false,

    // CacheConfiguration cache:
    null,

    // EnvironmentProperty[] environmentProperties:
    null,

    // String displayNameAttributeName:
    'displayName',

    // String mailAddressAttributeName:
    'mail',

    // IdStrategy userIdStrategy:
    null,

    // IdStrategy groupIdStrategy:
    null)

Jenkins.instance.save()
EOF
# verify that we can resolve an LDAP user and group.
# see http://javadoc.jenkins-ci.org/hudson/security/SecurityRealm.html
# see http://javadoc.jenkins-ci.org/hudson/security/GroupDetails.html
jgroovy = <<'EOF'
import jenkins.model.Jenkins

// resolve a user.
// NB u is-a org.acegisecurity.userdetails.ldap.LdapUserDetailsImpl.
u = Jenkins.instance.securityRealm.loadUserByUsername("vagrant")
u.authorities.sort().each { println sprintf("LDAP user %s authority: %s", u.username, it) }

// resolve a group.
// NB g is-a hudson.security.LDAPSecurityRealm$GroupDetailsImpl.
g = Jenkins.instance.securityRealm.loadGroupByGroupname("Enterprise Admins")
println sprintf("LDAP group: %s", g.name)
EOF
fi

# create example accounts (when using jenkins authentication).
# see http://javadoc.jenkins-ci.org/hudson/model/User.html
# see http://javadoc.jenkins-ci.org/hudson/security/HudsonPrivateSecurityRealm.html
# see https://github.com/jenkinsci/mailer-plugin/blob/master/src/main/java/hudson/tasks/Mailer.java
if [ "$config_authentication" = 'jenkins' ]; then
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
fi


#
# create credential to be used to create vagrant environments in vsphere.

jgroovy = <<'EOF'
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl
import com.cloudbees.plugins.credentials.SystemCredentialsProvider

c = new UsernamePasswordCredentialsImpl(
    CredentialsScope.GLOBAL,
    "vagrant-vsphere",          // id
    "vsphere.example.com",      // description
    "jenkins",                  // username
    "HeyH0Password")            // password

SystemCredentialsProvider.instance.store.addCredentials(
    Domain.global(),
    c)

null // return nothing.
EOF


#
# create artifacts that need to be shared with the other nodes.

mkdir -p /vagrant/tmp
pushd /vagrant/tmp
cp /var/lib/jenkins/.ssh/id_rsa.pub $domain-ssh-rsa.pub
cp /etc/ssl/private/$domain-crt.pem .
openssl x509 -outform der -in $domain-crt.pem -out $domain-crt.der
popd


#
# add the ubuntu slave node.
# see http://javadoc.jenkins-ci.org/jenkins/model/Jenkins.html
# see http://javadoc.jenkins-ci.org/jenkins/model/Nodes.html
# see http://javadoc.jenkins-ci.org/hudson/slaves/DumbSlave.html
# see http://javadoc.jenkins-ci.org/hudson/model/Computer.html

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.slaves.DumbSlave
import hudson.slaves.CommandLauncher

node = new DumbSlave(
    "ubuntu",
    "/var/jenkins",
    new CommandLauncher("ssh ubuntu.jenkins.example.com /var/jenkins/bin/jenkins-slave"))
node.numExecutors = 3
node.labelString = "ubuntu 20.04 linux amd64"
node.mode = 'EXCLUSIVE'
Jenkins.instance.nodesObject.addNode(node)
Jenkins.instance.nodesObject.save()
EOF


#
# add the windows slave node.

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.slaves.DumbSlave
import hudson.slaves.JNLPLauncher

node = new DumbSlave(
    "windows",
    "c:/j",
    new JNLPLauncher(true))
node.numExecutors = 3
node.labelString = "windows 2022 vs2022 vagrant docker amd64"
node.mode = 'EXCLUSIVE'
Jenkins.instance.nodesObject.addNode(node)
Jenkins.instance.nodesObject.save()
EOF


#
# add the macos slave node.

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.slaves.DumbSlave
import hudson.slaves.CommandLauncher

node = new DumbSlave(
    "macos",
    "/var/jenkins",
    new CommandLauncher("ssh macos.jenkins.example.com /var/jenkins/bin/jenkins-slave"))
node.numExecutors = 3
node.labelString = "macos 10.12 amd64"
node.mode = 'EXCLUSIVE'
Jenkins.instance.nodesObject.addNode(node)
Jenkins.instance.nodesObject.save()
EOF


#
# share the slave jnlp secrets with the other nodes.

(
jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.slaves.SlaveComputer

Jenkins.instance.computers
        .findAll { it instanceof SlaveComputer }
        .each { println("${it.name}\t${it.jnlpMac}") }
EOF
) | awk '/.+\t.+/ { printf "%s",$2 > "/vagrant/tmp/slave-jnlp-secret-" $1 ".txt" }'
