---
layout: post
title: Switching from BlobBackup to rclone
comments: true
tags: [blobbackup, rclone, veracrypt, backup, settings]
date: 2023-06-18
mastodon_id: 110564398385024030
---

In the [previous post]({% post_url switching-from-hubic-to-blobbackup %}) I used [BlobBackup](https://blobbackup.com/) to sync my backup data to a cloud storage and an external drive. Since then the original client hasn't been updated and an account is now mandatory to download and use it. Even if the offer is attractive I didn't want to change my cloud backup location and prefer to know where my data is stored.

So after an extensive search I choose [rclone](https://rclone.org/) to replace it mainly for the following reasons:
- allows access to individual folders and files (even if it means bigger uploads)
- well-known open-source software
- numerous targets (remotes in rclone language) including those that suit me: [S3 - Scaleway](https://rclone.org/s3/#scaleway) and [local filesystem](https://rclone.org/local/)
- handles [encryption of any remote](https://rclone.org/crypt/) and of the [configuration](https://rclone.org/docs/#configuration-encryption)

For the cloud backup I just had to add a new remote to my Scaleway storage named `Scaleway`, another one to encrypt the first named `ScalewayEncrypted` and encrypted the configuration.  
It is doable in command line but now there is even an [experimental gui](https://rclone.org/gui/).

For the external drive backup, a remote configuration wasn't necessary and I choose to encrypt the entire drive and not only the backup data.  
I have chosen [VeraCrypt](https://veracrypt.fr/en/) for the following reasons:
- well-known open-source software
- audited
- simple to use

Like the backup script I have written a powershell script to ease the sync from and to the cloud and external drive, I will detail it bit by bit:
```powershell
param(
    [Parameter(Mandatory = $True, Position = 0)]
    [string]
    $syncDirection,
    [Parameter(Mandatory = $True, Position = 1)]
    [string]
    $syncType,
    [Parameter(Mandatory = $False, Position = 2)]
    [string]
    $overrideLocalRoot
)

$ErrorActionPreference = "Stop"
. $PSScriptRoot\Toast.ps1

enum SyncType {
    Cloud
    Local
}

enum SyncDirection {
    To
    From
}
```
The parameters allows to easily define the sync direction and type, sadly since `param` must be at the top it can't use the enums directly.  
The local root path can be overridden, specially useful for testing a restore and not lose data.  

For the popup notification I use [BurntToast](https://github.com/Windos/BurntToast), here is the `Toast.ps1`:
```powershell
enum Icon {
    Info
    Error
}

# Icons from Roselin Christina.S from Noun Project
$icons = @{
    [Icon]::Info = "$PSScriptRoot\info.png";  # https://thenounproject.com/icon/info-1156901/
    [Icon]::Error = "$PSScriptRoot\error.png" # https://thenounproject.com/icon/error-1156903/
}

function Pop-Toast([string] $title, [string] $message, [Icon] $icon)
{
    New-BurntToastNotification -AppLogo $icons[$icon] -Text $title, $message
}
```

Now the sync configuration part:
```powershell
class SyncConfiguration {
    [ScriptBlock] $getRemote
    [string] $additionalParameters
}

function Get-DriveLetter([string] $driveName) {
    return (Get-CimInstance -ClassName Win32_Volume | ? { $_.Label?.ToLower() -eq $driveName }).DriveLetter
}

function Get-KasullRemote {
    $kasullLetter = Get-DriveLetter 'kasull'

    while ($null -eq $kasullLetter) {
        Write-Host 'Please insert Kasull, mount it in veracrypt and press a key' -ForegroundColor DarkGreen
        $null = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $kasullLetter = Get-DriveLetter 'kasull'
    }

    return "$kasullLetter\Backup\"
}

$syncConfigurations = @{
    [SyncType]::Cloud = [SyncConfiguration]@{ getRemote = { "ScalewayEncrypted:rclone/" }; additionalParameters = "--ask-password=false" };
    [SyncType]::Local = [SyncConfiguration]@{ getRemote = { Get-KasullRemote } }
}

class BackupEntry {
    [string] $name
    [string] $localParentPath
}

function Get-BackupEntries() {
    return @(
        [BackupEntry]@{ name = 'Backup'; localParentPath = "D:\" }
        [BackupEntry]@{ name = 'Archives'; localParentPath = "D:\" }
        [BackupEntry]@{ name = 'Photos'; localParentPath = "M:\" }
    )
}

$rclone = "D:\Softwares\rclone\rclone.exe"
```
Sync configurations are defined for the cloud and local. Since VeraCrypt can mount a drive on any letter, the letter of the external drive is detected with his name.  
To fully automate the sync the rclone password is taken from an environment variable hence the `--ask-password=false`.
After that the folders to sync are also defined.

And the last part of the script which determine the rclone arguments and calls it:
```powershell
try {
    $syncConfiguration = $syncConfigurations[[SyncType]$syncType]

    $title = "Sync $syncDirection $syncType"

    .$rclone selfupdate

    Pop-Toast $title 'Started' Info

    if (![string]::IsNullOrEmpty($overrideLocalRoot) -and !$overrideLocalRoot.EndsWith("\")) {
        $overrideLocalRoot += "\"
    }

    foreach ($backupEntry in Get-BackupEntries) {
        $syncSource = "$([string]::IsNullOrEmpty($overrideLocalRoot) ? $backupEntry.localParentPath : $overrideLocalRoot)$($backupEntry.name)"
        $syncDestination = "$($syncConfiguration.getRemote.invoke())$($backupEntry.name)"

        if ([SyncDirection]$syncDirection -ne [SyncDirection]::To) {
            $destTemp = $syncSource
            $syncSource = $syncDestination
            $syncDestination = $destTemp
        }

        Write-Host "Sync $($backupEntry.name)" -ForegroundColor DarkGreen
        .$rclone sync --progress $syncConfiguration.additionalParameters $syncSource $syncDestination
    }

    Pop-Toast $title 'Finished' Info
}
catch {
    Pop-Toast $title 'Error' Error
    Write-Host 'An error occurred:'
    Write-Host $_.ScriptStackTrace
    Write-Host $_
    Read-Host -Prompt 'Press enter to close'
}
```
The script can be invoked like this `SyncBackup.ps1 To Cloud` or `SyncBackup.ps1 From Local`.

And finally I created two tasks to launch the syncs regularly:
```powershell
# SyncToCloud
$action = New-ScheduledTaskAction -Execute 'pwsh' -Argument '-File D:\Backup\Scripts\SyncBackup.ps1 To Cloud'
$trigger = New-ScheduledTaskTrigger -Daily -At 2AM
$description = "Sync data to the cloud"
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun
Register-ScheduledTask -TaskName "SyncToCloud" -Action $action -Trigger $trigger -Description $description -RunLevel Highest -Settings $settings

# SyncToKasull
$action = New-ScheduledTaskAction -Execute 'pwsh' -Argument '-File D:\Backup\Scripts\SyncBackup.ps1 To Local'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 5AM
$description = "Sync data to Kasull"
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun
Register-ScheduledTask -TaskName "SyncToKasull" -Action $action -Trigger $trigger -Description $description -RunLevel Highest -Settings $settings
```

And that's it! (for now at least)