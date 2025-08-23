#!/bin/bash
set -eux
domain=$(hostname --fqdn)
source /vagrant/jenkins-cli.sh


#
# show install summary.

systemctl status jenkins
jcliwait
jcli version
jcli list-plugins | sort
jgroovy = <<'EOF'
import hudson.model.AbstractItem
import hudson.model.User
import jenkins.model.Jenkins

Jenkins.instance.nodes.sort { it.name }.each {
    name = it.name
    println sprintf("jenkins %s node", name)
    it.assignedLabels.sort().each { println sprintf("jenkins %s node label: %s", name, it) }
}
println "jenkins controller node"
Jenkins.instance.assignedLabels.sort().each { println "jenkins controller node label: " + it }
User.all.sort { it.id }.each { println sprintf("jenkins user: %s (%s)", it.id, it.fullName) }
Jenkins.instance.getAllItems(AbstractItem.class).sort { it.fullName }.each {
    println sprintf("jenkins job: %s (%s)", it.fullName, it.class)
}
EOF
echo "jenkins is installed at https://$domain"
echo "the admin password is $(cat /var/lib/jenkins/secrets/initialAdminPassword)"
echo "you can also use the vagrant user with the vagrant password"
