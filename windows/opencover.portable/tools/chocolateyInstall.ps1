# NB this version came from https://github.com/opencover/opencover/commit/416acac2c32ca572726735f7c22c3673d85a95aa
$url = 'https://ci.appveyor.com/api/buildjobs/782sipil03c8sd3l/artifacts/main%2Fbin%2Fzip%2Fopencover.4.6.829.zip'
$checksum = '95a4ffa444b875ea881c38598a33380aba92279dc24dbaacbefb450a8620b451'
$installPath = "$env:ChocolateyPackageFolder\tools"

Install-ChocolateyZipPackage `
    -PackageName $env:ChocolateyPackageName `
    -Url $url `
    -Checksum $checksum `
    -ChecksumType 'sha256' `
    -UnzipLocation $installPath

# only create a shim for OpenCover.Console.exe.
Get-ChildItem `
    $installPath `
    -Include *.exe `
    -Exclude OpenCover.Console.exe `
    -Recurse `
    | ForEach-Object {New-Item "$($_.FullName).ignore" -Type File -Force} `
    | Out-Null
