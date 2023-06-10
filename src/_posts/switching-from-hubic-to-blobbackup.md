---
layout: post
title: Switching from Hubic to BlobBackup
comments: true
tags: [hubic, blobbackup, backup, settings]
date: 2021-11-28
tweet_id: 1464896453457981446
---

It's important to do backups.  
I had one in place for all my important documents, encrypted locally and synced with Hubic. But since it is becoming out of commission and the last time I tried to do a restore the data was corrupted, I though that it was time to replace it.

### Usage
First I needed to rethink my use of backups: I was only doing backup of some important files in a cloud provider.  
My plan was to add my photos, some other documents and my software settings to the backup for ~25GB and the backup should be done in cloud and on a local external hard drive.

### Settings backup
I have a hard drive with the OS and softwares and another drive with the data to avoid losing them if I need to wipe the OS clean.  
The idea was just to copy the settings of certain softwares I use in order to be able to restore them after a fresh install of Windows.  
I have written a quick powershell script (I'm tempted to make it a more robust application):
```powershell
#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
$dataFolder = "D:\Backup\Data"

$balloon = New-Object System.Windows.Forms.NotifyIcon
$balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Process -id $pid).Path)

function ToastNotification([string] $message, [System.Windows.Forms.ToolTipIcon] $icon) {
    $balloon.BalloonTipIcon = $icon
    $balloon.BalloonTipText = $message
    $balloon.BalloonTipTitle = $message
    $balloon.Visible = $true
    $balloon.ShowBalloonTip(5000)
}

function CreateBackupDir([string] $dirName) {
    if (-not (Test-Path "$dataFolder\$dirName")) {
        New-Item -ItemType Directory -Force -Path "$dataFolder\$dirName"
    }
}

function DeleteDir([string] $dirName) {
    if (Test-Path "$dataFolder\$dirName") {
        Remove-Item -path "$dataFolder\$dirName" -recurse -force
    }
}

try {
    ToastNotification 'Backup started' Info

    # Jellyfin
    $jellyfinBackupPath = "$dataFolder\JellyfinServer.7z"
    Write-Host 'Backup Jellyfin' -ForegroundColor DarkGreen
    # 1. Stop Jellyfin
    Write-Host 'Stopping service' -ForegroundColor DarkGray
    Stop-Service 'JellyfinServer'
    # 2. Make a copy of all the Jellyfin data and configuration directories
    Write-Host 'Copying data' -ForegroundColor DarkGray
    &'C:\Program Files\7-Zip\7z.exe' a $jellyfinBackupPath 'C:\ProgramData\Jellyfin\Server' -mx=0 -aoa
    # 3. Start Jellyfin
    Write-Host 'Starting service' -ForegroundColor DarkGray
    Start-Service 'JellyfinServer'

    # Firefox dev tabs
    Write-Host 'Backup Firefox' -ForegroundColor DarkGreen
    CreateBackupDir 'Firefox'
    Copy-Item -Path "$env:APPDATA\Mozilla\Firefox\Profiles\*.dev-edition-default\sessionstore-backups\recovery.jsonlz4" -Destination "$dataFolder\Firefox"
    Copy-Item -Path "$env:APPDATA\Mozilla\Firefox\Profiles\*.dev-edition-default\sessionstore-backups\recovery.baklz4" -Destination "$dataFolder\Firefox"

    # Powershell profile
    Write-Host 'Backup Powershell' -ForegroundColor DarkGreen
    if (Test-Path -Path "$env:USERPROFILE\Documents\Powershell")
    {
        Copy-Item -Path "$env:USERPROFILE\Documents\Powershell\Microsoft.PowerShell_profile.ps1" -Destination "$dataFolder\" –Force
    }
    else
    {
        Copy-Item -Path "$env:USERPROFILE\OneDrive\Documents\Powershell\Microsoft.PowerShell_profile.ps1" -Destination "$dataFolder\" –Force
    }

    # BlobBackup
    Write-Host 'Backup BlobBackup' -ForegroundColor DarkGreen
    CreateBackupDir 'BlobBackup'
    Copy-Item -Path "$env:USERPROFILE\.blobbackup\*" -Destination "$dataFolder\BlobBackup\"

    # Notepad++
    Write-Host 'Backup Notepad++' -ForegroundColor DarkGreen
    CreateBackupDir 'Notepad++'
    DeleteDir 'notepad++\backup'
    Copy-Item -Path "$env:AppData\Notepad++\config.xml" -Destination "$dataFolder\Notepad++"
    Copy-Item -Path "$env:AppData\Notepad++\session.xml" -Destination "$dataFolder\Notepad++"
    Copy-Item -Path "$env:AppData\Notepad++\backup" -Destination "$dataFolder\Notepad++" -Recurse

    ToastNotification 'Backup finished' Info
}
catch {
    ToastNotification 'Backup error' Error
    Write-Host 'An error occurred:'
    Write-Host $_.ScriptStackTrace
    Write-Host $_
    Read-Host -Prompt 'Press enter to close'
}
```
*Edit: Thanks to [Loïc Wolff](https://twitter.com/loicwolff) the administrator check has been simplified with a `#requires` and the notifications are now grouped together.*  
It requires to be launched as administrator to be able to stop and restart the [Jellyfin](https://jellyfin.org/) service, it copies the settings of various softwares in a specific folder and raise a notification ([Thanks to Boe Prox](https://mcpmag.com/articles/2017/09/07/creating-a-balloon-tip-notification-using-powershell.aspx)), alerting me if an error showed.  
*Edit 2: Since then I discovered that the notifications do not stay in the notification center of Windows 11 so I switched to [BurntToast](https://github.com/Windos/BurntToast/):*
```powershell
enum Icon {
    Info
    Error
}

# Icons from Roselin Christina.S from Noun Project
# https://thenounproject.com/icon/error-1156903/
# https://thenounproject.com/icon/info-1156901/
$icons = @{
    [Icon]::Info = ".\info.png";
    [Icon]::Error = ".\error.png"
}

function Pop-Toast([string] $title, [string] $message, [Icon] $icon)
{
    New-BurntToastNotification -AppLogo $icons[$icon] -Text $title, $message
}
```

A scheduled task allows me to run it every day:
```powershell
$taskAction = New-ScheduledTaskAction -Execute 'pwsh' -Argument '-File Backup.ps1'
$taskTrigger = New-ScheduledTaskTrigger -Daily -At 1AM
$taskName = "Backup"
$description = "Backup settings of applications"

Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Description $description -RunLevel Highest
```

### Search for a replacement
Next step was to search for a replacement of Hubic. After a quick search I turned to [rclone](https://rclone.org/) which is very versatile but seems a little bit complex for my taste.  
Luckily a french blogger I follow published an [article](https://korben.info/blobbackup-sauvegarde.html) at that time on a backup software which seems to check all my boxes.  
[BlobBackup](https://github.com/BlobBackup/BlobBackup) is simple to use, handles many backup destinations including local directory and S3 compatible storages, is open-source and encrypts data.

But there are some inconveniences:
- it is still in beta, although very stable
- it hasn't an included cloud storage ([for now](https://www.reddit.com/r/BlobBackup/comments/nrm9yd/bitwardenlike_business_model_ideas/)) which forces me to search for one

### Cloud storage
My requirements were an S3 compatible storage preferably located in France or europe, and I found [Scaleway](https://www.scaleway.com) which is a french cloud provider and has a free [Object Storage plan](https://www.scaleway.com/en/object-storage/) up to 75Go.

I just had to create an account, fill in my credit card to had access to the creation of an S3 bucket and the last thing to do was to create an API key.

### BlobBackup Configuration
BlobBackup is very easy to configure, you choose a storage location, fill in the backup name and password and set the storage parameters.  
After that you choose the folders to include in the backup, maybe define exclude rules and a schedule and can even specify a retention.

For my needs, I have configured a backup to an external hard drive scheduled every week on sunday 5AM and a backup to my Scaleway object storage bucket every day at 2AM.

### Quick feedback
I have only used BlobBackup since ~15 days, but here are my quick feedback.  
There are some issues, with [storage parameters modification](https://github.com/BlobBackup/BlobBackup/issues/74) for example, due to his young age but it is open-source and [you can help](https://github.com/BlobBackup/BlobBackup/pull/76) build it.  
About his performance, I have ~25 Go of data to backup and thanks to his incremental engine for the backup to the external drive it has taken about ~17 minutes the first time and now it is down to 49 secondes. Of course it depends if many files have been modified.
