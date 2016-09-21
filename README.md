This is a [Vagrant](https://www.vagrantup.com/) Environment for a Continuous Integration server using the [Jenkins](https://jenkins.io) daemon.

This configures Jenkins through [CLI/JNLP](https://wiki.jenkins-ci.org/display/JENKINS/Jenkins+CLI) and [Groovy](http://www.groovy-lang.org/) scripts to:

* Enable the simple `Logged-in users can do anything` Authorization security policy.
* Add a SSH public key to `admin` user account and use it to access the CLI.
* Add and list users.
* Install and configure plugins.
* Setup nginx as a Jenkins HTTPS proxy and static file server.
* Create a simple Free Style Project job.
* Add a Ubuntu Linux slave node.
* Add a Windows slave node.

**NB** If you are new to Groovy, be sure to check the [Groovy Learn X in Y minutes page](https://learnxinyminutes.com/docs/groovy/).

These are the machines and how they are connected with each other:

<img src="diagram.svg">


# Usage

Build and install the [Ubuntu Base Box](https://github.com/rgl/ubuntu-vagrant).

Build and install the Windows Base Box with:

```bash
git clone https://github.com/joefitzgerald/packer-windows
cd packer-windows
# this will take ages to build, so leave it running over night...
packer build windows_2012_r2.json
vagrant box add windows_2012_r2 windows_2012_r2_virtualbox.box
rm *.box
cd ..
```

Add the following entry to your `/etc/hosts` file:

```
10.10.10.100 jenkins.example.com
```

Install the following Vagrant plugin:

```bash
vagrant plugin install vagrant-triggers # see https://github.com/emyl/vagrant-triggers
```

Run `vagrant up jenkins` to launch the master. See its output to known how to login at the
[local Jenkins home page](https://jenkins.example.com) as `admin` (you can also login with
one of the example accounts, e.g. `alice.doe` and password `password`).

**NB** nginx is setup with a self-signed certificate that you have to trust before being able to access the local Jenkins home page.

Run `vagrant up ubuntu` to launch the Ubuntu slave.

Run `vagrant up windows` to launch the Windows slave.
