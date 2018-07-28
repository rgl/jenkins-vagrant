#!/bin/bash
set -eux
domain=$(hostname --fqdn)
source /vagrant/jenkins-cli.sh


#
# create example free style jobs.
# see http://javadoc.jenkins-ci.org/jenkins/model/Jenkins.html
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
[Environment]::OSVersion | Format-Table -AutoSize
$PSVersionTable | Format-Table -AutoSize
'''))

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
import hudson.tasks.Mailer
import org.jenkinsci.plugins.xunit.XUnitBuilder
import org.jenkinsci.lib.dtkit.type.TestType
import org.jenkinsci.plugins.xunit.types.XUnitDotNetTestType
import org.jenkinsci.plugins.xunit.threshold.XUnitThreshold
import org.jenkinsci.plugins.xunit.threshold.FailedThreshold
import org.jenkinsci.plugins.xunit.threshold.SkippedThreshold

project = new FreeStyleProject(Jenkins.instance, 'MailBounceDetector')
project.assignedLabel = new LabelAtom('vs2017')
project.scm = new GitSCM('https://github.com/rgl/MailBounceDetector.git')
project.scm.branches = [new BranchSpec('*/master')]
project.scm.extensions.add(new CleanBeforeCheckout())
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
            failureThreshold: '',
            failureNewThreshold: '',
        )
    ] as XUnitThreshold[], // thresholds
    1,      // thresholdMode
    '3000'  // testTimeMargin
))
project.publishersList.add(
    new ArtifactArchiver('**/*.nupkg,**/*-report.*'))

project.publishersList.add(
    new Mailer('jenkins@example.com', true, false))

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
exec {dotnet pack -v n -c Release --no-build -p:PackageVersion=0.0.1 --output .}

cd ../ExampleApplication
exec {dotnet build -v n -c Release}
exec {dotnet sourcelink print-urls bin/Release/netcoreapp2.0/ExampleApplication.dll}
exec {dotnet sourcelink print-json bin/Release/netcoreapp2.0/ExampleApplication.dll | ConvertFrom-Json | ConvertTo-Json -Depth 100}
exec {dotnet sourcelink print-documents bin/Release/netcoreapp2.0/ExampleApplication.dll}
dotnet run
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
