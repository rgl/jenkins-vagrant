# NB this version came from https://github.com/opencover/opencover/commit/2010793db8e4288accaf3484a76e072cb253eac8
$url = 'https://ci.appveyor.com/api/buildjobs/v57oxenhb8sogf6p/artifacts/main%2Fbin%2Fzip%2Fopencover.4.6.796.zip'
$checksum = '444a336ee4049f1ee5e9c305942a8988c3974fb9679aeaa0d9b611e471f0feb9'
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
