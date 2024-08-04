---
layout: post
title: Installing and updating GE-Proton automatically
comments: true
tags: [linux, steam, proton, flatpak]
date: 2024-08-02
mastodon_id: 
---

I recently switched from Windows to Linux, [Pop!_OS](https://pop.system76.com/) specificatlly, (and still in the process if I'm being honest) and one of my concerns was about running games since it is one of the things I do most.  
Thankfully [Valve](https://www.valvesoftware.com/) have been working for years to port [Steam](https://store.steampowered.com/about/) on Linux for their console Steam Deck but it was profitable for all distros. Amongst other things Valve have developed [Proton](https://github.com/ValveSoftware/Proton): it is a tool for use with the Steam client which allows games which are exclusive to Windows to run on Linux by using [Wine](https://www.winehq.org/). It work great for most games sold on Steam, but for some or for games obtained elsewhere even the experimental version of Proton is not enough.

This is where [GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom) shines: it is a fork of Proton which adds some games compatibility and stay on the edge of Wine releases.  
There is many ways to install it (like an [asdf plugin](https://github.com/augustobmoura/asdf-protonge), [ProtonUp-Qt](https://davidotek.github.io/protonup-qt/), unofficial [flatpak](https://github.com/flathub/com.valvesoftware.Steam.CompatibilityTool.Proton-GE)) but I wanted a script to be able to run it regularly and didn't know if I stick to the flatpak version of Steam preinstalled on Pop!_OS or if I will switch to the native version, so I modified the install bash script to be used in either case:

``` bash
#!/bin/bash
# Update GE Proton
set -euo pipefail

githubReleaseUrl="https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest"
compatibilityToolsDir=compatibilitytools.d/
steamNativeDir=~/.steam/root/
steamFlatpakDir=~/.var/app/com.valvesoftware.Steam/data/Steam/
tmpDir=/tmp/proton-ge-custom

if [ -d "$steamNativeDir" ]; then
  dir="$steamNativeDir$compatibilityToolsDir"
elif [ -d "$steamFlatpakDir" ]; then
  dir="$steamFlatpakDir$compatibilityToolsDir"
else
  echo "steam not installed or installation not supported"
  exit 1
fi

# make steam directory if it does not exist
mkdir -p $dir

latestRelease=$(curl -s $githubReleaseUrl)
version=$(echo "$latestRelease" | grep tag_name | cut -d\" -f4)

# check if version already installed
if [ -d "$dir$version" ]; then
  echo "latest version $version already installed"
  exit 0
fi

# make temp working directory
mkdir $tmpDir
cd $tmpDir

echo "installing version $version"

# download tarball
curl -sLOJ "$(echo "$latestRelease" | grep browser_download_url | cut -d\" -f4 | grep .tar.gz)"

# download checksum
curl -sLOJ "$(echo "$latestRelease" | grep browser_download_url | cut -d\" -f4 | grep .sha512sum)"

# check tarball with checksum
sha512sum -c ./*.sha512sum

# extract proton tarball to steam directory
tar -xf GE-Proton*.tar.gz -C $dir

# copy release notes
echo -e "$(echo "$latestRelease" | grep body | cut -d\" -f4)" >> "$dir$version/release_note.txt"

cd ..
rm -r $tmpDir

echo "version $version installed"
```

There is no deletion of the previous versions because they can still be configured on steam to be used for some installed games.{.info}

And now to update it weekly, copy it to `/etc/cron.weekly`:
``` sh
sudo cp GE-Proton-install-update.sh /etc/cron.weekly/GE-Proton-install-update
```
Make it executable:
``` sh
sudo chmod +x /etc/cron.weekly/GE-Proton-install-update
```
And just to be sure you can test it.  
See if it will be executed:
``` sh
run-parts --test /etc/cron.weekly
```
Or execute all weekly jobs with their names:
``` sh
run-parts --verbose /etc/cron.weekly
```

Happy gaming!

Sources:
- <https://github.com/GloriousEggroll/proton-ge-custom>
- <https://github.com/ValveSoftware/Proton>
- <https://stackoverflow.com/a/29509403/424072>
- <https://stackoverflow.com/a/18878111/424072>