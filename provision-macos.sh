#!/bin/bash
set -eux

config_fqdn=$(hostname)
config_jenkins_master_fqdn=$(hostname | sed -E 's,^[a-z]+\.,,')


#
# rename the hard disk.

diskutil rename disk0s2 macOS


#
# install Xcode.

if [[ ! -f /vagrant/Xcode_8.1.cpio.xz ]]; then
pushd /vagrant
pkgutil --verbose --check-signature Xcode_8.1.xip
xar -xf Xcode_8.1.xip
curl -sO https://gist.githubusercontent.com/pudquick/ff412bcb29c9c1fa4b8d/raw/24b25538ea8df8d0634a2a6189aa581ccc6a5b4b/parse_pbzx2.py
python parse_pbzx2.py Content
rm Content
mv Content.part00.cpio.xz Xcode_8.1.cpio.xz
shasum -a 256 Xcode_8.1.cpio.xz >Xcode_8.1.cpio.xz.shasum
rm Xcode_8.1.xip
popd
fi
sudo bash <<'SUDO_EOF'
set -eux
cd /vagrant
shasum -c Xcode_8.1.cpio.xz.shasum
cd /Applications
cpio -idmu </vagrant/Xcode_8.1.cpio.xz
xcodebuild -license accept
for pkg in Xcode.app/Contents/Resources/Packages/*.pkg; do
    installer -pkg "$pkg" -target /
done
SUDO_EOF


#
# install homebrew.

ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" </dev/null
#brew analytics off


#
# configure vim.

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

cat >~/.bash_profile <<'EOF'
# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

export EDITOR=vim
export PAGER=less

alias l='ls -lFG'
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

brew cask install java


#
# add the jenkins system user.

sudo bash <<'SUDO_EOF'
set -eux
USER_NAME=jenkins
USER_REAL_NAME='Jenkins Slave'
USER_GID=$(($(dscl . -list /Groups PrimaryGroupID | awk '{print $2}' | sort -ug | tail -1)+1))
USER_UID=$(($(dscl . -list /Users  UniqueID       | awk '{print $2}' | sort -ug | tail -1)+1))
dscl . -create /Groups/_$USER_NAME
dscl . -create /Groups/_$USER_NAME RecordName _$USER_NAME $USER_NAME
dscl . -create /Groups/_$USER_NAME PrimaryGroupID $USER_GID
dscl . -create /Groups/_$USER_NAME Password '*'
dscl . -create /Users/_$USER_NAME
dscl . -create /Users/_$USER_NAME RealName "$USER_REAL_NAME"
dscl . -create /Users/_$USER_NAME RecordName _$USER_NAME $USER_NAME
dscl . -create /Users/_$USER_NAME UniqueID $USER_UID
dscl . -create /Users/_$USER_NAME PrimaryGroupID $USER_GID
dscl . -create /Users/_$USER_NAME UserShell /bin/bash
dscl . -create /Users/_$USER_NAME NFSHomeDirectory /var/$USER_NAME
dscl . -create /Users/_$USER_NAME Password '*'
dscl . -delete /Users/_$USER_NAME AuthenticationAuthority
dscl . -delete /Users/_$USER_NAME PasswordPolicyOptions
dseditgroup -o edit -t user -a $USER_NAME com.apple.access_ssh
launchctl stop com.openssh.sshd
launchctl start com.openssh.sshd
#dscl . -read Users/_$USER_NAME
install -d -o $USER_NAME -g $USER_NAME -m 750 /var/$USER_NAME
SUDO_EOF


#
# install the slave.

sudo bash <<SUDO_EOF
set -eux
pushd /var/jenkins
install -d -o jenkins -g jenkins -m 750 {bin,lib,.ssh}
install -o jenkins -g jenkins -m 640 /dev/null .ssh/authorized_keys
cat /vagrant/tmp/$config_jenkins_master_fqdn-ssh-rsa.pub >>.ssh/authorized_keys
security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /vagrant/tmp/$config_jenkins_master_fqdn-crt.pem
cat >bin/jenkins-slave <<EOF
#!/bin/sh
exec java -jar \$PWD/lib/slave.jar
EOF
chmod +x bin/jenkins-slave
curl -sf https://$config_jenkins_master_fqdn/jnlpJars/slave.jar -o lib/slave.jar
popd
SUDO_EOF


#
# create artifacts that need to be shared with the other nodes.

sudo bash <<SUDO_EOF
set -eux
mkdir -p /vagrant/tmp
pushd /vagrant/tmp
find \
    /etc/ssh \
    -name 'ssh_host_*_key.pub' \
    -exec bash -c "(echo -n '$config_fqdn '; cat {})" \; \
    >$config_fqdn.ssh_known_hosts
popd
SUDO_EOF


#
# show summary.

system_profiler SPSoftwareDataType
sw_vers
uname -a
xcode-select -version
xcode-select -print-path
xcodebuild -version
swift -version
java -version
python --version
ruby --version
git --version
brew config
df -h /
