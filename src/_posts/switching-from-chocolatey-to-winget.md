---
layout: post
title: Switching from Chocolatey to Winget
comments: true
tags: [chocolatey, winget, boxstarter, powershell]
date: 2021-11-24
tweet_id: 
---

Around every 2-3 years I reinstall my computer with a fresh Windows.  
To avoid loosing to much time, I use [Boxstarter](https://boxstarter.org/) and [Chocolatey](https://chocolatey.org/) to automate as much as possible all settings and softwares installations.  
But since I use Chocolatey only on that occasion, I wanted to replace it by [Winget](https://docs.microsoft.com/en-us/windows/package-manager/winget/): is is (almost) native to windows, the v1.0 is out and the number of packages available in the [community repository](https://github.com/microsoft/winget-pkgs) is good enough.

Both are package managers and are invoked from the command line, so the switch was not hard but there was some differences and deficiencies to come by.

### Installing winget
Winget will be integrated with Windows 11 but it is not yet a reality, so to be sure to have the right version installed I use this:
```powershell
$hasPackageManager = Get-AppPackage -name 'Microsoft.DesktopAppInstaller'
if (!$hasPackageManager -or [version]$hasPackageManager.Version -lt [version]"1.10.0.0") {
    Start-Process ms-appinstaller:?source=https://aka.ms/getwinget
    Read-Host -Prompt "Press enter to continue..."
}
```
I use the prompt to pause the script since I need winget for the rest.

### Package arguments

Chocolatey allows packages creators to add parameters directly for the package, which allows to install Git, add it to the path and disables shell integration with this command:

``` bash
choco install git.install --params "/GitOnlyOnPath /NoShellIntegration"
```

Winget doesn't allow package creators to add parameters since it handles directly the installers, but you can override the parameters passed to the installer.  
So to install git the same way than above, you can use the `--override` parameter which looks like this:

``` bash
winget install --id Git.Git --override '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCANCEL /SP- /LOG /COMPONENTS="assoc,gitlfs" /o:PathOption=Cmd'
```
Since you override all parameters, you have to pass the silent ones and the ones you want to add.

It can be hard to find the parameters of the installer, for git you can see in [this issue](https://github.com/git-for-windows/git/issues/2912) that they have added a `/o:` arg which overrides the parameters defined in the [installer definition](https://github.com/git-for-windows/build-extra/blob/HEAD/installer/install.iss), specifically the arguments passed to the [ReplayChoice function](https://github.com/git-for-windows/build-extra/blob/HEAD/installer/install.iss#L1140). For the components, they are defined in the [[Components]](https://github.com/git-for-windows/build-extra/blob/HEAD/installer/install.iss#L105) section.

Here are some other examples:  
**Visual Studio Code**  
Choco:
``` bash
choco install vscode --params "/NoDesktopIcon /NoQuicklaunchIcon"
```
Winget:
``` bash
winget install --id Microsoft.VisualStudioCode --override '/VERYSILENT /SUPPRESSMSGBOXES /MERGETASKS="!runcode,!desktopicon,!quicklaunchicon"'
```
The `!runcode` task allows to not run Visual Studio Code once installed.

**Sumatra PDF**  
Choco:
``` bash
choco install sumatrapdf.install --params "/WithPreview"
```
Winget:
``` bash
winget install --id SumatraPDF.SumatraPDF --override '/install /S -with-preview'
```

### Missing packages
Some packages where missing from the [community repository](https://github.com/microsoft/winget-pkgs), but it is quite easy to create a new one with [winget create](https://github.com/microsoft/winget-create) or, if you want to automate that, with the [YamlCreate script](https://github.com/microsoft/winget-pkgs#using-the-yamlcreateps1).  
For example I quickly added [Cybersoft.DriversCloud](https://github.com/microsoft/winget-pkgs/pull/34590) and [Jellyfin.JellyfinServer](https://github.com/microsoft/winget-pkgs/pull/34735).  
And if you want the packages to keep up to dates with the releases, you can raise a new issue in the [winget-pkgs-automation repository](https://github.com/vedantmgoyal2009/winget-pkgs-automation) or better, make a new PR to [add the required infos and maybe script necessary to automate the updates](https://github.com/vedantmgoyal2009/winget-pkgs-automation/pull/194).

But Winget is still limited to installers like msi, msix and exe so I had to handle the packages without installers otherwise.

For standalone exe I chose to download them but not to add them to the path contrary to Chocolatey:
``` powershell
iwr https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe -out "$env:USERPROFILE\Downloads\OOSU10.exe"
```
Since it concerns only exe that will be used only once, the add to path is not necessary.  
To ease the process I made it a function:
```powershell
function Download ($url) {
    $fileName =  Split-Path $url -leaf
    $downloadPath = "$env:USERPROFILE\Downloads\$fileName"
    iwr $url -out $downloadPath
    return $downloadPath
}
```

Same for zip files:
``` powershell
function UnzipFromWeb ($url) {
    $downloadPath = Download $url
    $targetDir = "$env:USERPROFILE\Downloads\$(Get-ChildItem $downloadPath | Select-Object -ExpandProperty BaseName)"
    Expand-Archive $downloadPath -DestinationPath $targetDir -Force
    Remove-Item $downloadPath
    return $targetDir
}
```
Which is used like this:
```powershell
UnzipFromWeb 'https://github.com/microsoft/Terminal/releases/download/1904.29002/ColorTool.zip'
```

For font it is a little bit more difficult:
```powershell
$cascadiaCodeFolder = UnzipFromWeb 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip'
$fonts = (New-Object -ComObject Shell.Application).Namespace(0x14)
foreach ($file in "$cascadiaCodeFolder\*.ttf")
{
    $fileName = $file.Name
    dir $file | %{ $fonts.CopyHere($_.fullname) }
}
Remove-Item $cascadiaCodeFolder -Recurse -Force
```
The code is adapted from [Simon Timms blog post](https://blog.simontimms.com/2021/06/11/installing-fonts/).

### Boxstarter and Chocolatey uninstall
Since I will not use them after that, I chose to uninstall both Boxstarter and Chocolatey.  
It is not easy but the code is available on their website: for [boxstarter](https://boxstarter.org/InstallBoxstarter) (at the bottom) and for [Chocolatey](https://chocolatey.org/docs/uninstallation).  
Be careful thought, since it modify the path it can cause quite a damage on your computer.
