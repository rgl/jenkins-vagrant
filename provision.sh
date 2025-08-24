#!/bin/bash
set -eux

domain=$(hostname --fqdn)

# see https://www.jenkins.io/download/
jenkins_version='2.516.2'

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
# set the system timezone.

timedatectl set-timezone Europe/Lisbon


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
wget -qO /etc/ssl/certs/dhparam.pem https://ssl-config.mozilla.org/ffdhe2048.txt
sed -i -E 's/^(\s*)((ssl_protocols|ssl_ciphers|ssl_prefer_server_ciphers)\s)/\1# \2/' /etc/nginx/nginx.conf
cat >/etc/nginx/conf.d/local.conf <<EOF
# NB this is based on the mozilla intermediate configuration.
# see https://ssl-config.mozilla.org/#server=nginx&version=1.18.0&config=intermediate&openssl=3.0.2&guideline=5.7
# see https://packages.ubuntu.com/jammy/nginx
# see https://packages.ubuntu.com/jammy/openssl
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ecdh_curve X25519:prime256v1:secp384r1;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m; # about 40000 sessions.
ssl_session_timeout 1d;
ssl_session_tickets on;
ssl_dhparam /etc/ssl/certs/dhparam.pem;
# NB our example ca does not support stapling, so this is commented.
#ssl_stapling on;
#ssl_stapling_verify on;
#ssl_trusted_certificate /etc/ssl/certs/jenkins-ca.pem;
#resolver 127.0.0.53 valid=30s;
#resolver_timeout 5s;
EOF
cat >/etc/nginx/sites-available/jenkins <<EOF
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
    ssl_certificate_key /etc/ssl/private/$domain-key.pem;
    add_header Strict-Transport-Security "max-age=31536000" always;

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

apt-get install -y openjdk-21-jre-headless
apt-get install -y gnupg
apt-get install -y xmlstarlet


#
# fix "java.lang.NoClassDefFoundError: Could not initialize class org.jfree.chart.JFreeChart"
# error while rendering the xUnit Test Result Trend chart on the job page.

sed -i -E 's,^(\s*assistive_technologies\s*=.*),#\1,' /etc/java-21-openjdk/accessibility.properties


#
# install Jenkins.
# see https://pkg.jenkins.io/debian-stable/

wget -qO /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian/jenkins.io-2023.key
echo 'deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/' >/etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y --no-install-recommends "jenkins=$jenkins_version"
pushd /var/lib/jenkins
# wait for initialization to finish.
bash -c 'while ! wget -q --spider http://localhost:8080/health/; do sleep 1; done;'
bash -c 'while [ ! -f "/var/lib/jenkins/secrets/initialAdminPassword" ]; do sleep 1; done'
systemctl stop jenkins
chmod 751 /var/cache/jenkins
mv config.xml{,.orig}
# remove the xml 1.1 declaration because xmlstarlet does not support it... and xml 1.1 is not really needed.
tail -n +2 config.xml.orig >config.xml
# disable security.
# see https://www.jenkins.io/doc/book/security/access-control/disable/
xmlstarlet edit --inplace -u '/hudson/useSecurity' -v 'false' config.xml
xmlstarlet edit --inplace -d '/hudson/authorizationStrategy' config.xml
xmlstarlet edit --inplace -d '/hudson/securityRealm' config.xml
# see https://www.jenkins.io/doc/book/system-administration/systemd-services/
install -d /etc/systemd/system/jenkins.service.d
install /dev/null /etc/systemd/system/jenkins.service.d/override.conf
cat >>/etc/systemd/system/jenkins.service.d/override.conf <<'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true"
EOF
# disable the install wizard.
sed -i -E 's,^(Environment="JAVA_OPTS=-.+)",\1 -Djenkins.install.runSetupWizard=false",' /etc/systemd/system/jenkins.service.d/override.conf
# modify the agent workspace directory name to be just "w" as a way to minimize
# path-too-long errors on windows agents.
# NB unfortunately this setting applies to all agents.
# NB in a pipeline job you can also use the customWorkspace option.
# see windows/provision-jenkins-agent.ps1.
# see https://issues.jenkins.io/browse/JENKINS-12667
# see https://www.jenkins.io/doc/book/managing/system-properties/
# see https://github.com/jenkinsci/jenkins/blob/jenkins-2.516.2/core/src/main/java/hudson/model/Slave.java#L796-L799
sed -i -E 's,^(Environment="JAVA_OPTS=-.+)",\1 -Dhudson.model.Slave.workspaceRoot=w",' /etc/systemd/system/jenkins.service.d/override.conf
# bind to localhost.
cat >>/etc/systemd/system/jenkins.service.d/override.conf <<'EOF'
Environment="JENKINS_LISTEN_ADDRESS=127.0.0.1"
EOF
# show the configuration changes.
diff -u config.xml{.orig,} || true
popd
systemctl daemon-reload
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
# see https://javadoc.jenkins.io/jenkins/model/Jenkins.html
jgroovy = <<'EOF'
import hudson.model.Node.Mode
import jenkins.model.Jenkins

// disable usage statistics.
Jenkins.instance.noUsageStatistics = true

// do not run jobs on the controller.
Jenkins.instance.numExecutors = 0
Jenkins.instance.mode = Mode.EXCLUSIVE

Jenkins.instance.save()
EOF

# set the jenkins url and administrator email.
# see https://javadoc.jenkins.io/jenkins/model/JenkinsLocationConfiguration.html
jgroovy = <<EOF
import jenkins.model.JenkinsLocationConfiguration

c = JenkinsLocationConfiguration.get()
c.url = 'https://$domain'
c.adminAddress = 'Jenkins <jenkins@example.com>'
c.save()
EOF

# install and configure git.
apt-get install -y git
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
# see https://javadoc.jenkins.io/jenkins/model/Jenkins.html
# see https://javadoc.jenkins.io/hudson/PluginManager.html
# see https://javadoc.jenkins.io/hudson/model/UpdateCenter.html
# see https://javadoc.jenkins.io/hudson/model/UpdateSite.Plugin.html
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
    'oidc-provider',            // aka OpenID Connect Provider;     see https://plugins.jenkins.io/oidc-provider
    'ldap',                     // aka LDAP;                        see https://plugins.jenkins.io/ldap
    'command-launcher',         // aka Command Agent Launcher;      see https://plugins.jenkins.io/command-launcher
    'cloudbees-folder',         // aka Folders;                     see https://plugins.jenkins.io/cloudbees-folder
    'email-ext',                // aka Email Extension;             see https://plugins.jenkins.io/email-ext
    'gitlab-plugin',            // aka GitLab;                      see https://plugins.jenkins.io/gitlab-plugin
    'git',                      // aka Git;                         see https://plugins.jenkins.io/git
    'powershell',               // aka Jenkins PowerShell Plugin;   see https://plugins.jenkins.io/powershell
    'xcode-plugin',             // aka Xcode plugin;                see https://plugins.jenkins.io/xcode-plugin
    'xunit',                    // aka xUnit;                       see https://plugins.jenkins.io/xunit
    'conditional-buildstep',    // aka Conditional BuildStep;       see https://plugins.jenkins.io/conditional-buildstep
    'workflow-aggregator',      // aka Pipeline;                    see https://plugins.jenkins.io/workflow-aggregator
    'ws-cleanup',               // aka Workspace Cleanup;           see https://plugins.jenkins.io/ws-cleanup
    'docker-workflow',          // aka Docker Pipeline;             see https://plugins.jenkins.io/docker-workflow
    'timestamper',              // aka Timestamper;                 see https://plugins.jenkins.io/timestamper
    'simple-theme-plugin',      // aka Simple Theme;                see https://plugins.jenkins.io/simple-theme-plugin
    'dark-theme',               // aka Dark Theme;                  see https://plugins.jenkins.io/dark-theme
    'chocolate-theme',          // aka Chocolate Theme;             see https://plugins.jenkins.io/chocolate-theme
].each {
  install(it)
}
EOF
}
while [[ -n "$(install-plugins)" ]]; do
    systemctl restart jenkins
    jcliwait
done

# use the local SMTP Mailpit server.
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

# generate the SSH key-pair that jenkins controller uses to communicates with the agents.
su jenkins -c 'ssh-keygen -q -t rsa -N "" -f ~/.ssh/id_rsa'

# set the allowed agent protocols.
# NB JNLP4-connect will be used by windows nodes.
# see https://javadoc.jenkins.io/jenkins/model/Jenkins.html
jgroovy = <<'EOF'
import jenkins.model.Jenkins

Jenkins.instance.agentProtocols = ["JNLP4-connect", "Ping"]
Jenkins.instance.slaveAgentPort = 50000
Jenkins.instance.save()
EOF

# enable simple security.
# also create the vagrant user account. jcli will use this account from now on.
# see https://javadoc.jenkins.io/hudson/security/HudsonPrivateSecurityRealm.html
# see https://javadoc.jenkins.io/hudson/model/User.html
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
# see https://javadoc.jenkins.io/hudson/model/User.html
# see https://javadoc.jenkins.io/jenkins/security/ApiTokenProperty.html
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
# see https://javadoc.jenkins.io/hudson/model/User.html
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
# see https://plugins.jenkins.io/ldap/
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
# see https://javadoc.jenkins.io/hudson/security/SecurityRealm.html
# see https://javadoc.jenkins.io/hudson/security/GroupDetails.html
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
# see https://javadoc.jenkins.io/hudson/model/User.html
# see https://javadoc.jenkins.io/hudson/security/HudsonPrivateSecurityRealm.html
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
popd


#
# configure the appearance.

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import io.jenkins.plugins.chocolatetheme.ChocolateTheme
import io.jenkins.plugins.darktheme.DarkThemeSystemManagerFactory
import org.jenkinsci.plugins.simpletheme.CssTextThemeElement

c = Jenkins.instance.getDescriptor("io.jenkins.plugins.thememanager.ThemeManagerPageDecorator")
//c.theme = new DarkThemeSystemManagerFactory()
c.theme = new ChocolateTheme()
c.save()

c = Jenkins.instance.getDescriptor("org.codefirst.SimpleThemeDecorator")
c.elements = [new CssTextThemeElement(
    '''\
    pre.console-output .timestamp {
        opacity: 0.5;
        margin-right: 1ch;
    }
    pre#out.console-output .timestamp {
        margin-right: 0;
    }
    '''.stripIndent())]
c.save()
EOF


#
# configure the timestamper plugin.

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.plugins.timestamper.TimestamperConfig

c = TimestamperConfig.get()
c.allPipelines = true
c.systemTimeFormat = "yyyy-MM-dd HH:mm:ss.SSS"
c.elapsedTimeFormat = "HH:mm:ss.SSS"
c.save()
EOF


#
# add the ubuntu agent node.
# see https://javadoc.jenkins.io/jenkins/model/Jenkins.html
# see https://javadoc.jenkins.io/jenkins/model/Nodes.html
# see https://javadoc.jenkins.io/hudson/slaves/DumbSlave.html
# see https://javadoc.jenkins.io/hudson/slaves/ComputerLauncher.html
# see https://javadoc.jenkins.io/hudson/model/Computer.html

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.slaves.DumbSlave
import hudson.slaves.CommandLauncher

node = new DumbSlave(
    "ubuntu",
    "/var/jenkins",
    new CommandLauncher("ssh ubuntu.jenkins.example.com /var/jenkins/bin/jenkins-agent"))
node.numExecutors = 3
node.labelString = "ubuntu 22.04 linux docker amd64"
node.mode = 'EXCLUSIVE'
Jenkins.instance.nodesObject.addNode(node)
Jenkins.instance.nodesObject.save()
EOF


#
# add the windows agent node.

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
# add the macos agent node.

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.slaves.DumbSlave
import hudson.slaves.CommandLauncher

node = new DumbSlave(
    "macos",
    "/var/jenkins",
    new CommandLauncher("ssh macos.jenkins.example.com /var/jenkins/bin/jenkins-agent"))
node.numExecutors = 3
node.labelString = "macos 10.12 amd64"
node.mode = 'EXCLUSIVE'
Jenkins.instance.nodesObject.addNode(node)
Jenkins.instance.nodesObject.save()
EOF


#
# share the agent jnlp secrets with the other nodes.

(
jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.slaves.SlaveComputer

Jenkins.instance.computers
        .findAll { it instanceof SlaveComputer }
        .each { println("${it.name}\t${it.jnlpMac}") }
EOF
) | awk '/.+\t.+/ { printf "%s",$2 > "/vagrant/tmp/agent-jnlp-secret-" $1 ".txt" }'


#
# approve all the pending scripts.
# see https://javadoc.jenkins.io/plugin/script-security/org/jenkinsci/plugins/scriptsecurity/scripts/ScriptApproval.html
# see https://jenkins.example.com/manage/scriptApproval/
# NB the pending and approved scripts are in /var/lib/jenkins/scriptApproval.xml
#    for example:
#       <approvedScriptHashes>
#         <string>SHA512:ee4138444442c3b814fa7f236f936f630adf2c65e11089eddc55d75d7c092dc7e37ff9aa2047a3ae76ded9cfa1ca42a0276a81ad71b1a648903d2315bedac780</string>
#       </approvedScriptHashes>
#       <pendingScripts>
#         <pendingScript>
#           <context>
#             <user>vagrant</user>
#           </context>
#           <script>ssh ubuntu.jenkins.example.com /var/jenkins/bin/jenkins-agent</script>
#           <language>system-command</language>
#         </pendingScript>
#       </pendingScripts>
# TODO find a better way, and just approve the ssh agent commands.

jgroovy = <<'EOF'
import org.jenkinsci.plugins.scriptsecurity.scripts.ScriptApproval

ScriptApproval scriptApproval = ScriptApproval.get()
scriptApproval.pendingScripts.toList().each {
    scriptApproval.approveScript(it.hash)
}
EOF


#
# configure the oidc provider id-token claims.
# see /var/lib/jenkins/io.jenkins.plugins.oidc_provider.config.IdTokenConfiguration.xml
# see https://github.com/jenkinsci/oidc-provider-plugin/blob/master/src/main/java/io/jenkins/plugins/oidc_provider/config/IdTokenConfiguration.java
# NB GIT_URL, GIT_BRANCH and GIT_COMMIT are not available as build claims.

jgroovy = <<'EOF'
import io.jenkins.plugins.oidc_provider.config.ClaimTemplate
import io.jenkins.plugins.oidc_provider.config.IdTokenConfiguration
import io.jenkins.plugins.oidc_provider.config.IntegerClaimType
import io.jenkins.plugins.oidc_provider.config.StringClaimType
import io.jsonwebtoken.Claims

IdTokenConfiguration.get().buildClaimTemplates = [
    new ClaimTemplate(Claims.SUBJECT, "\${JOB_URL}", new StringClaimType()),
    new ClaimTemplate("build_number", "\${BUILD_NUMBER}", new IntegerClaimType()),
    new ClaimTemplate("node_name", "\${NODE_NAME}", new StringClaimType()),
]

null // return nothing.
EOF


#
# create an example oidc provider id-token credential.
# see https://plugins.jenkins.io/oidc-provider
# see https://javadoc.jenkins.io/plugin/oidc-provider/io/jenkins/plugins/oidc_provider/IdTokenCredentials.html
# NB the jwks endpoint is at https://jenkins.example.com/oidc/jwks

jgroovy = <<'EOF'
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import io.jenkins.plugins.oidc_provider.IdTokenStringCredentials

c = new IdTokenStringCredentials(
    CredentialsScope.GLOBAL,
    "oidc-id-token-example",
    "For https://example.com")
c.audience = "https://example.com"

SystemCredentialsProvider.instance.store.addCredentials(
    Domain.global(),
    c)

null // return nothing.
EOF
