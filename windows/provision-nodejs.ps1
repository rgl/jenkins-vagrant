# install node.js.
# see https://community.chocolatey.org/packages/nodejs
# renovate: datasource=nuget:chocolatey depName=nodejs versioning=node
$nodejsVersion = '24.21.0'
choco install -y nodejs --version $nodejsVersion
