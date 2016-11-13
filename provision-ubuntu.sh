#!/bin/bash
set -eux

config_fqdn=$(hostname --fqdn)
config_jenkins_master_fqdn=$(hostname --domain)

echo 'Defaults env_keep += "DEBIAN_FRONTEND"' >/etc/sudoers.d/env_keep_apt
chmod 440 /etc/sudoers.d/env_keep_apt
export DEBIAN_FRONTEND=noninteractive


#
# make sure the package index cache is up-to-date before installing anything.

apt-get update


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

cat >~/.bashrc <<'EOF'
# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

export EDITOR=vim
export PAGER=less

alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
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
# install dependencies.

apt-get install -y default-jre


#
# add the jenkins user.

groupadd --system jenkins
adduser \
    --system \
    --disabled-login \
    --no-create-home \
    --gecos '' \
    --ingroup jenkins \
    --home /var/jenkins \
    --shell /bin/bash \
    jenkins


#
# install the slave.

install -d -o jenkins -g jenkins -m 750 /var/jenkins
pushd /var/jenkins
install -d -o jenkins -g jenkins -m 750 {bin,lib,.ssh}
install -o jenkins -g jenkins -m 640 /dev/null .ssh/authorized_keys
cat /vagrant/tmp/$config_jenkins_master_fqdn-ssh-rsa.pub >>.ssh/authorized_keys
cp /vagrant/tmp/$config_jenkins_master_fqdn-crt.pem /usr/local/share/ca-certificates/$config_jenkins_master_fqdn.crt
update-ca-certificates # NB this also updates the default java key store at /etc/ssl/certs/java/cacerts.
cat >bin/jenkins-slave <<EOF
#!/bin/sh
exec java -jar $PWD/lib/slave.jar
EOF
chmod +x bin/jenkins-slave
wget -q https://$config_jenkins_master_fqdn/jnlpJars/slave.jar -O lib/slave.jar
popd


#
# create artifacts that need to be shared with the other nodes.

mkdir -p /vagrant/tmp
pushd /vagrant/tmp
find \
    /etc/ssh \
    -name 'ssh_host_*_key.pub' \
    -exec sh -c "(echo -n '$config_fqdn '; cat {})" \; \
    >$config_fqdn.ssh_known_hosts
popd
