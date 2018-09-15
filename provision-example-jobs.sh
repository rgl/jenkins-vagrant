#!/bin/bash
set -eux
domain=$(hostname --fqdn)
source /vagrant/jenkins-cli.sh


#
# create example jobs.
# see https://jenkins.io/doc/pipeline/steps/
# see http://javadoc.jenkins-ci.org/jenkins/model/Jenkins.html
# see http://javadoc.jenkins.io/plugin/workflow-job/org/jenkinsci/plugins/workflow/job/WorkflowJob.html
# see http://javadoc.jenkins.io/plugin/workflow-cps/org/jenkinsci/plugins/workflow/cps/CpsFlowDefinition.html
# see http://javadoc.jenkins-ci.org/hudson/model/FreeStyleProject.html
# see http://javadoc.jenkins-ci.org/hudson/model/Label.html
# see http://javadoc.jenkins-ci.org/hudson/tasks/Shell.html
# see http://javadoc.jenkins-ci.org/hudson/tasks/ArtifactArchiver.html
# see http://javadoc.jenkins-ci.org/hudson/tasks/BatchFile.html
# see http://javadoc.jenkins.io/plugin/mailer/hudson/tasks/Mailer.html
# see https://github.com/jenkinsci/powershell-plugin/blob/master/src/main/java/hudson/plugins/powershell/PowerShell.java
# see https://github.com/jenkinsci/git-plugin/blob/master/src/main/java/hudson/plugins/git/GitSCM.java
# see https://github.com/jenkinsci/git-plugin/blob/master/src/main/java/hudson/plugins/git/extensions/impl/CleanBeforeCheckout.java
# see https://github.com/jenkinsci/xunit-plugin/blob/master/src/main/java/org/jenkinsci/plugins/xunit/XUnitBuilder.java

# create the dump-environment folder to contain all of our dump jobs.
jgroovy = <<'EOF'
import jenkins.model.Jenkins
import com.cloudbees.hudson.plugins.folder.Folder

folder = new Folder(Jenkins.instance, 'dump-environment')
folder.save()

Jenkins.instance.add(folder, folder.name)
EOF

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.model.FreeStyleProject
import hudson.model.labels.LabelAtom
import hudson.tasks.Shell

folder = Jenkins.instance.getItem('dump-environment')

project = new FreeStyleProject(folder, 'linux')
project.assignedLabel = new LabelAtom('linux')
project.buildersList.add(new Shell(
'''\
cat /etc/lsb-release
uname -a
env
locale
id
'''))

folder.add(project, project.name)
EOF

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition

folder = Jenkins.instance.getItem('dump-environment')

project = new WorkflowJob(folder, 'linux-pipeline')
project.definition = new CpsFlowDefinition("""\
pipeline {
    agent {
        label 'linux'
    }
    stages {
        stage('Build') {
            steps {
                sh '''
cat /etc/lsb-release
uname -a
env
locale
id
'''
            }
        }
    }
}
""",
true)

folder.add(project, project.name)
EOF

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.model.FreeStyleProject
import hudson.model.labels.LabelAtom
import hudson.plugins.powershell.PowerShell
import hudson.tasks.BatchFile

folder = Jenkins.instance.getItem('dump-environment')

project = new FreeStyleProject(folder, 'windows')
project.assignedLabel = new LabelAtom('windows')
project.buildersList.add(new BatchFile(
'''\
set
whoami /all
'''))
project.buildersList.add(new PowerShell(
'''\
function Write-Title($title) {
    Write-Host "`n#`n# $title`n"
}

Write-Title 'PATH Environment Variable'
$env:PATH -split ';'

Write-Title '[Environment]::OSVersion'
[Environment]::OSVersion | Format-Table -AutoSize

Write-Title '$PSVersionTable'
$PSVersionTable | Format-Table -AutoSize
'''))

folder.add(project, project.name)
EOF

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition

folder = Jenkins.instance.getItem('dump-environment')

project = new WorkflowJob(folder, 'windows-pipeline')
project.definition = new CpsFlowDefinition("""\
pipeline {
    agent {
        label 'windows'
    }
    stages {
        stage('Build') {
            steps {
                bat '''
set
whoami /all
'''
                powershell '''
function Write-Title(\$title) {
    Write-Host "`n#`n# \$title`n"
}

Write-Title 'PATH Environment Variable'
\$env:PATH -split ';'

Write-Title '[Environment]::OSVersion'
[Environment]::OSVersion | Format-Table -AutoSize

Write-Title '\$PSVersionTable'
\$PSVersionTable | Format-Table -AutoSize
'''
            }
        }
    }
}
""",
true)

folder.add(project, project.name)
EOF

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.model.FreeStyleProject
import hudson.model.labels.LabelAtom
import hudson.tasks.Shell

folder = Jenkins.instance.getItem('dump-environment')

project = new FreeStyleProject(folder, 'macos')
project.assignedLabel = new LabelAtom('macos')
project.buildersList.add(new Shell(
'''\
system_profiler SPSoftwareDataType
sw_vers
uname -a
env
locale
id
'''))

folder.add(project, project.name)
EOF

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.model.FreeStyleProject
import hudson.model.labels.LabelAtom
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.GitSCM
import hudson.plugins.git.extensions.impl.CleanBeforeCheckout
import hudson.plugins.powershell.PowerShell
import hudson.tasks.ArtifactArchiver
import hudson.tasks.BatchFile
import hudson.tasks.Mailer
import org.jenkinsci.plugins.xunit.XUnitBuilder
import org.jenkinsci.lib.dtkit.type.TestType
import org.jenkins_ci.plugins.run_condition.core.StatusCondition
import org.jenkins_ci.plugins.run_condition.BuildStepRunner
import org.jenkinsci.plugins.conditionalbuildstep.singlestep.SingleConditionalBuilder
import org.jenkinsci.plugins.xunit.types.XUnitDotNetTestType
import org.jenkinsci.plugins.xunit.threshold.XUnitThreshold
import org.jenkinsci.plugins.xunit.threshold.FailedThreshold
import org.jenkinsci.plugins.xunit.threshold.SkippedThreshold

project = new FreeStyleProject(Jenkins.instance, 'MailBounceDetector')
project.assignedLabel = new LabelAtom('vs2017')

//
// add the git repository.

project.scm = new GitSCM('https://github.com/rgl/MailBounceDetector.git')
project.scm.branches = [new BranchSpec('*/master')]
project.scm.extensions.add(new CleanBeforeCheckout())

//
// add build steps.

project.buildersList.add(new PowerShell(
'''\
$ErrorActionPreference = 'Stop'

MSBuild -m -p:Configuration=Release -t:restore -t:build
if ($LastExitCode) {
    Exit $LastExitCode
}

dir -Recurse */bin/*.Tests.dll | ForEach-Object {
    Push-Location $_.Directory
    Write-Host "Running the unit tests in $($_.Name)..."
    # NB maybe you should also use -skipautoprops
    OpenCover.Console.exe `
        -output:opencover-report.xml `
        -register:path64 `
        '-filter:+[*]* -[*.Tests*]* -[*]*.*Config -[xunit.*]*' `
        '-target:xunit.console.exe' `
        "-targetargs:$($_.Name) -nologo -noshadow -xml xunit-report.xml"
    ReportGenerator.exe `
        -reports:opencover-report.xml `
        -targetdir:coverage-report
    Compress-Archive `
        -CompressionLevel Optimal `
        -Path coverage-report/* `
        -DestinationPath coverage-report.zip
    Pop-Location
}
'''))
project.buildersList.add(new XUnitBuilder(
    [
        new XUnitDotNetTestType(
            '**/xunit-report.xml', // pattern
            false,  // skipNoTestFiles
            true,   // failIfNotNew
            true,   // deleteOutputFiles
            true    // stopProcessingIfError
        )
    ] as TestType[], // types
    [
        new FailedThreshold(
            unstableThreshold: '',
            unstableNewThreshold: '',
            failureThreshold: '0',
            failureNewThreshold: '',
        ),
        new SkippedThreshold(
            unstableThreshold: '',
            unstableNewThreshold: '',
            failureThreshold: '0',
            failureNewThreshold: '',
        )
    ] as XUnitThreshold[], // thresholds
    1,      // thresholdMode
    '3000'  // testTimeMargin
))
project.buildersList.add(new SingleConditionalBuilder(
    new BatchFile(                  // buildStep
'''\
:: when there are tests failures, the previous xUnit build-step only
:: marks the build as failed, it does not aborts it. this step will
:: really abort it.
:: see https://github.com/jenkinsci/xunit-plugin/pull/62
@echo Aborting the build due to test failures...
@exit 1
'''),
    new StatusCondition(            // condition
        'FAILURE',  // worstResult
        'FAILURE'), // bestResult
    new BuildStepRunner.Fail()))    // runner

//
// add post-build steps.

project.publishersList.add(
    new ArtifactArchiver('**/*.nupkg,**/*-report.*'))
project.publishersList.add(
    new Mailer('jenkins@example.com', true, false))

Jenkins.instance.add(project, project.name)
EOF

jgroovy = <<'EOF'
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.extensions.impl.CleanBeforeCheckout
import hudson.plugins.git.GitSCM
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import org.jenkinsci.plugins.workflow.job.WorkflowJob

scm = new GitSCM('https://github.com/rgl/MailBounceDetector.git')
scm.branches = [new BranchSpec('*/master')]
scm.extensions.add(new CleanBeforeCheckout())

project = new WorkflowJob(Jenkins.instance, 'MailBounceDetector-pipeline')
project.definition = new CpsScmFlowDefinition(scm, 'Jenkinsfile')

Jenkins.instance.add(project, project.name)
EOF

jgroovy = <<'EOF'
import com.cloudbees.hudson.plugins.folder.computed.DefaultOrphanedItemStrategy
import com.cloudbees.hudson.plugins.folder.computed.PeriodicFolderTrigger
import jenkins.branch.BranchSource
import jenkins.model.Jenkins
import jenkins.plugins.git.GitSCMSource
import jenkins.plugins.git.traits.BranchDiscoveryTrait
import jenkins.plugins.git.traits.CleanBeforeCheckoutTrait
import org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject

scm = new GitSCMSource('https://github.com/rgl/MailBounceDetector.git')
scm.traits = [
    new BranchDiscoveryTrait(),
    new CleanBeforeCheckoutTrait()]

project = new WorkflowMultiBranchProject(Jenkins.instance, 'MailBounceDetector-multibranch-pipeline')
project.sourcesList.add(new BranchSource(scm))
project.projectFactory.scriptPath = 'Jenkinsfile'
project.addTrigger(new PeriodicFolderTrigger('1d'))
project.orphanedItemStrategy = new DefaultOrphanedItemStrategy(
    true,   // pruneDeadBranches
    -1,     // daysToKeepStr
    3)      // numToKeepStr
//project.scheduleBuild2(0) // schedule a Scan Multibranch Pipeline and Build all branches.

Jenkins.instance.add(project, project.name)
EOF

jgroovy = <<'EOF'
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.extensions.impl.CleanBeforeCheckout
import hudson.plugins.git.GitSCM
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import org.jenkinsci.plugins.workflow.job.WorkflowJob

scm = new GitSCM('https://github.com/rgl/example-dotnet-source-link.git')
scm.branches = [new BranchSpec('*/master')]
scm.extensions.add(new CleanBeforeCheckout())

project = new WorkflowJob(Jenkins.instance, 'example-dotnet-source-link-pipeline')
project.definition = new CpsScmFlowDefinition(scm, 'Jenkinsfile')

Jenkins.instance.add(project, project.name)
EOF

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.model.FreeStyleProject
import hudson.model.labels.LabelAtom
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.GitSCM
import hudson.plugins.git.extensions.impl.CleanBeforeCheckout
import hudson.plugins.powershell.PowerShell

project = new FreeStyleProject(Jenkins.instance, 'example-dotnet-source-link')
project.assignedLabel = new LabelAtom('vs2017')
project.scm = new GitSCM('https://github.com/rgl/example-dotnet-source-link.git')
project.scm.branches = [new BranchSpec('*/master')]
project.scm.extensions.add(new CleanBeforeCheckout())
project.buildersList.add(new PowerShell(
'''\
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\\r?\\n') -replace '^(.*)$','ERROR: $1')
    Write-Output (($_.Exception.ToString() -split '\\r?\\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}
function exec([ScriptBlock]$externalCommand) {
    &$externalCommand
    if ($LASTEXITCODE) {
        throw "$externalCommand failed with exit code $LASTEXITCODE"
    }
}

cd ExampleLibrary
exec {dotnet build -v n -c Release}
exec {dotnet pack -v n -c Release --no-build -p:PackageVersion=0.0.2 --output .}

cd ../ExampleApplication
exec {dotnet build -v n -c Release}
exec {sourcelink print-urls bin/Release/netcoreapp2.1/ExampleApplication.dll}
exec {sourcelink print-json bin/Release/netcoreapp2.1/ExampleApplication.dll | ConvertFrom-Json | ConvertTo-Json -Depth 100}
exec {sourcelink print-documents bin/Release/netcoreapp2.1/ExampleApplication.dll}
dotnet run -v n -c Release --no-build
# force a success exit code because dotnet run is expected to fail due
# to an expected unhandled exception being raised by the application.
$LASTEXITCODE = 0
'''))

Jenkins.instance.add(project, project.name)
EOF

jgroovy = <<'EOF'
import jenkins.model.Jenkins
import hudson.model.FreeStyleProject
import hudson.model.labels.LabelAtom
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.GitSCM
import hudson.plugins.git.extensions.impl.CleanBeforeCheckout
import hudson.tasks.Shell
import hudson.tasks.ArtifactArchiver

project = new FreeStyleProject(Jenkins.instance, 'minimal-cocoa-app')
project.assignedLabel = new LabelAtom('macos')
project.scm = new GitSCM('https://github.com/rgl/minimal-cocoa-app.git')
project.scm.branches = [new BranchSpec('*/master')]
project.scm.extensions.add(new CleanBeforeCheckout())
project.buildersList.add(new Shell(
'''\
make build
'''))
project.buildersList.add(new Shell(
'''\
# package as a tarball
tar czf minimal-cocoa-app.app.tgz minimal-cocoa-app.app

# package as a dmg
[[ -d make_dmg ]] || git clone https://github.com/rgl/make_dmg.git
cd make_dmg
[[ -f background.png ]] || curl -sLO http://bitbucket.org/rgl/make_dmg/downloads/background.png
./make_dmg \
    -image background.png \
    -file 144,144 ../minimal-cocoa-app.app \
    -symlink 416,144 /Applications \
    -convert UDBZ \
    ../minimal-cocoa-app.dmg
'''))
project.publishersList.add(
    new ArtifactArchiver('*.tgz,*.dmg'))

Jenkins.instance.add(project, project.name)
EOF
