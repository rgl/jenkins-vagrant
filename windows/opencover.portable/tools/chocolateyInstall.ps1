# NB this version came from https://github.com/opencover/opencover/commit/c1e519513cd46d076da25bf036304ba97c169c5e
$url = 'https://ci.appveyor.com/api/buildjobs/q56vm4ilns3x7q9q/artifacts/main%2Fbin%2Fzip%2Fopencover.4.6.793.zip'
$checksum = '7dca757b4ff8c8f4f227b6bdf9289c267fbffce3116922386004a3b27a6ea473'
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
