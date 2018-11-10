$url = 'https://github.com/rgl/opencover/releases/download/v20181110/opencover-v20181110.zip'
$checksum = '25a3e5281200edbf1c428ef382fd2e1778294a5909595b95eeab0870a9f03d81'
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
