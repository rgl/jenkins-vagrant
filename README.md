This is a [Vagrant](https://www.vagrantup.com/) Environment for a Continuous Integration server using the [Jenkins](https://jenkins.io) daemon.

This configures Jenkins through [CLI/JNLP](https://wiki.jenkins-ci.org/display/JENKINS/Jenkins+CLI) and [Groovy](http://www.groovy-lang.org/) scripts to:

* Enable the simple `Logged-in users can do anything` Authorization security policy.
* Add a SSH public key to `admin` user account and use it to access the CLI.
* Add and list users.
* Install and configure plugins.
* Setup nginx as a Jenkins HTTPS proxy and static file server. 

If you are new to Groovy, be sure to check the [Groovy Learn X in Y minutes page](https://learnxinyminutes.com/docs/groovy/).


# Usage

Build and install the [Ubuntu Base Box](https://github.com/rgl/ubuntu-vagrant).

Add the following entry to your `/etc/hosts` file:

```
10.10.10.100 jenkins.example.com
``` 

Run `vagrant up` to launch the server and see its output to known how to login at the [local Jenkins home page](https://jenkins.example.com) as `admin`.

**NB** nginx is setup with a self-signed certificate that you have to trust before being able to access the local Jenkins home page.
