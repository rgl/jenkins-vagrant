# see https://blogs.msdn.microsoft.com/jeremykuhne/2016/07/30/net-4-6-2-and-long-paths-on-windows-10/
# see https://winaero.com/blog/how-to-enable-ntfs-long-paths-in-windows-10/


#
# patch the system.

# Enabling Win32 long paths will allow manifested win32 applications and
# Windows Store applications to access paths beyond the normal 260 character
# limit per node on file systems that support it.  Enabling this setting
# will cause the long paths to be accessible within the process.
Set-ItemProperty `
    -Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem `
    -Name LongPathsEnabled `
    -Value 1


#
# patch chocolatey.

function GetOrCreateXmlNode([xml]$xml, [string]$xpath, [Xml.XmlNamespaceManager]$ns) {
    $modified = $false
    $parentNode = $xml
    foreach ($segment in $xpath -split '/') {
        $node = $parentNode.SelectSingleNode($segment, $ns)
        if (!$node) {
            $parts = $segment -split ':'
            if ($parts.Count -eq 1) {
                $prefix = ''
                $localName = $parts[0]
            } else {
                $prefix = $parts[0]
                $localName = $parts[1]
            }
            $node = $parentNode.AppendChild($xml.CreateElement($localName, $ns.LookupNamespace($prefix)))
            $modified = $true
        }
        $parentNode = $node
    }
    return New-Object PSObject -Property @{
        node = $node
        modified = $modified
    }
}

# add support for long paths in .net with the
#   <configuration/runtime/AppContextSwitchOverrides value="Switch.System.IO.UseLegacyPathHandling=false;Switch.System.IO.BlockLongPaths=false" />
# element.
$configModified = $false
$configPath = "$env:ChocolateyInstall\choco.exe.config"
if (Test-Path $configPath) {
    $config = [xml](Get-Content $configPath)
} else {
    $config = [xml]'<configuration />'
    $configModified = $true
}
$ns = New-Object Xml.XmlNamespaceManager($config.NameTable)
$result = GetOrCreateXmlNode $config 'configuration/runtime/AppContextSwitchOverrides' $ns
$configModified = $configModified -or $result.modified
$appContextSwitchOverridesNode = $result.node
$expectedValue = 'Switch.System.IO.UseLegacyPathHandling=false;Switch.System.IO.BlockLongPaths=false'
if ($expectedValue -ne $appContextSwitchOverridesNode.GetAttribute('value')) {
    $appContextSwitchOverridesNode.SetAttribute('value', $expectedValue)
    $configModified = $true
}
if ($configModified = $true) {
    $config.Save($configPath)
}

# add support for long paths in win32 with the
#   <assembly/application/windowsSettings/longPathAware>true</longPathAware>
# element.
$manifestModified = $false
$manifestPath = "$env:ChocolateyInstall\choco.exe.manifest"
$manifest = [xml](Get-Content $manifestPath)
$ns = New-Object Xml.XmlNamespaceManager($manifest.NameTable)
$ns.AddNamespace('asmv1', 'urn:schemas-microsoft-com:asm.v1')
$ns.AddNamespace('asmv3', 'urn:schemas-microsoft-com:asm.v3')
$ns.AddNamespace('ws2016', 'http://schemas.microsoft.com/SMI/2016/WindowsSettings')
$result = GetOrCreateXmlNode $manifest 'asmv1:assembly/asmv3:application/asmv3:windowsSettings/ws2016:longPathAware' $ns
$manifestModified = $manifestModified -or $result.modified
$longPathAwareNode = $result.node
if ($longPathAwareNode.InnerText -ne 'true') {
    $longPathAwareNode.InnerText = 'true'
    $manifestModified = $true
}
if ($manifestModified) {
    $manifest.Save($manifestPath)
}
