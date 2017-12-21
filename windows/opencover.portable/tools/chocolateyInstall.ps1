# NB this version came from https://github.com/opencover/opencover/commit/ddb4437a731849f9fda6454e4c50ce4774517fd9
$url = 'https://ci.appveyor.com/api/buildjobs/69583xv18l3i0580/artifacts/main%2Fbin%2Fzip%2Fopencover.4.6.819.zip'
$checksum = 'b30353730d7757651fbab6bfbcf2443f04d5e648800130c7832ba0d3135a69b7'
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
