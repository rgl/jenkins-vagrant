#!/bin/bash
set -eux
domain=$(hostname --fqdn)
source /vagrant/jenkins-cli.sh


#
# add the gitlab user and save the api token.
# NB this user should only have Job/Build permissions to be able to trigger builds.
# NB this is used to globally trigger any job build from a gitlab web hook.
#    NB unfortunately, I was not able to make this work... let me known if you do!

jgroovy = >/vagrant/tmp/gitlab-api-token.txt <<'EOF'
import jenkins.model.Jenkins
import jenkins.security.ApiTokenProperty
import hudson.tasks.Mailer

if (Jenkins.instance.securityRealm.getClass().name.toLowerCase().contains('ldap')) {
    println 'disabled-when-using-ldap-auth-in-jenkins'
    return
}

[
    [id: "gitlab",   fullName: "GitLab"],
].each {
    u = Jenkins.instance.securityRealm.createAccount(it.id, "password")
    u.fullName = it.fullName
    u.addProperty(new Mailer.UserProperty(it.id+"@example.com"))
    u.save()
    p = u.getProperty(ApiTokenProperty)
    t = p.tokenStore.generateNewToken("gitlab.example.com")
    println t.plainValue
}

null // return nothing.
EOF


#
# add the jenkins gitlab api token credential.
# NB this is used to push build results into gitlab.

jenkins_gitlab_api_token="$(cat /vagrant/tmp/gitlab-jenkins-impersonation-token.txt || echo 'dummy-token')"
jgroovy = <<EOF
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.dabsquared.gitlabjenkins.connection.GitLabApiTokenImpl
import hudson.util.Secret

c = new GitLabApiTokenImpl(
    CredentialsScope.GLOBAL,
    "gitlab.example.com-api-token",                 // id
    "gitlab.example.com-api-token",                 // description
    Secret.fromString("$jenkins_gitlab_api_token")) // secret

SystemCredentialsProvider.instance.store.addCredentials(
    Domain.global(),
    c)

null // return nothing.
EOF


#
# configure the gitlab.example.com GitLab connection.
# see https://github.com/jenkinsci/gitlab-plugin/blob/master/src/main/java/com/dabsquared/gitlabjenkins/connection/GitLabConnectionConfig.java
# see https://github.com/jenkinsci/gitlab-plugin/blob/master/src/main/java/com/dabsquared/gitlabjenkins/connection/GitLabConnection.java

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import com.dabsquared.gitlabjenkins.connection.GitLabConnection
import com.dabsquared.gitlabjenkins.connection.GitLabConnectionConfig

c = Jenkins.instance.getDescriptorByType(GitLabConnectionConfig.class)
c.connections = c.connections.findAll{it.name} // remove all unnamed connections (by default there is one).
c.addConnection(new GitLabConnection(
    "gitlab.example.com",               // name
    "https://gitlab.example.com",       // url
    "gitlab.example.com-api-token",     // apiTokenId
    "v4",                               // clientBuilderId
    false,                              // ignoreCertificateErrors
    10,                                 // connectionTimeout (seconds)
    10))                                // readTimeout (seconds)
c.save()
EOF


#
# add the gitlab credentials.
# NB this is used to git checkout from gitlab repositories.
# see https://github.com/rgl/gitlab-vagrant/blob/master/create-example-jenkins-to-gitlab-configuration.sh

jgroovy = <<'EOF'
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl
import com.cloudbees.plugins.credentials.SystemCredentialsProvider

c = new UsernamePasswordCredentialsImpl(
    CredentialsScope.GLOBAL,
    "gitlab.example.com-git", // id
    "gitlab.example.com-git", // description
    "jenkins",                // username
    "password")               // password

SystemCredentialsProvider.instance.store.addCredentials(
    Domain.global(),
    c)

null // return nothing.
EOF


#
# add example job.
# see https://github.com/jenkinsci/gitlab-plugin/blob/a7e728515174abcde6bd5cf5a6b3347238101fef/src/main/java/com/dabsquared/gitlabjenkins/GitLabPushTrigger.java

jgroovy = <<'EOF'
import java.security.SecureRandom
import jenkins.model.Jenkins
import com.dabsquared.gitlabjenkins.GitLabPushTrigger
import com.dabsquared.gitlabjenkins.trigger.TriggerOpenMergeRequest
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition

folder = Jenkins.instance

project = new WorkflowJob(folder, 'test-jenkins-gitlab-plugin')
project.definition = new CpsFlowDefinition('''\
pipeline {
    agent {
        label 'windows'
    }
    options {
        gitLabConnection('gitlab.example.com')
    }
    stages {
        stage('Environment') {
            steps {
                bat 'set'
            }
        }
        stage('Git Merge') {
            // only run when triggered by gitlab and when the merge comes
            // from the same repository.
            when {
                not {
                    environment name: 'gitlabActionType', value: ''
                }
                expression {
                    !env.gitlabTargetRepoHttpUrl || env.gitlabTargetRepoHttpUrl == env.gitlabSourceRepoHttpUrl
                }
            }
            steps {
                checkout scm: [
                    $class: 'GitSCM',
                    branches: [[name: "origin/${env.gitlabSourceBranch}"]],
                    extensions: [
                        [$class: 'CleanBeforeCheckout'],
                        [$class: 'PreBuildMerge',
                            options: [
                                fastForwardMode: 'FF',
                                mergeRemote: 'origin',
                                mergeStrategy: 'DEFAULT',
                                mergeTarget: "${env.gitlabTargetBranch}"]]],
                    userRemoteConfigs: [
                        [name: 'origin',
                            credentialsId: 'gitlab.example.com-git',
                            url: 'https://gitlab.example.com/example/test-jenkins-gitlab-plugin.git']]]
            }
        }
        stage('Build') {
            steps {
                bat 'dir'
            }
        }
    }
    post {
        success {
            updateGitlabCommitStatus name: 'build', state: 'success'
        }
        failure {
            updateGitlabCommitStatus name: 'build', state: 'failed'
        }
    }
}
''',
true)
project.addTrigger(new GitLabPushTrigger(
    triggerOpenMergeRequestOnPush: TriggerOpenMergeRequest.source,
    secretToken: new SecureRandom().generateSeed(16).encodeHex().toString(), // 16-byte (128-bit).
))

folder.add(project, project.name)
EOF
