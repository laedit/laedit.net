---
layout: post
title: Migrate webextension repositories to sourcehut
comments: true
tags: [webextension, sourcehut, git]
date: 2026-10-23
mastodon_id: 
---

Still had some webextensions repos on Azure DevOps and decided to migrate them to [sourcehut](https://sourcehut.org/) (and still have some on github but i will migrate them later).

**Disclaimer**: This is in no way a precise how-to or maybe the best way to do that, i will just indicate the steps i followed for my case which is only git repositories and build pipelines.{.info}

### Moving the repo

It's the easy part:  
Create a project and an associated git repository at <https://sr.ht/>.  

Then change the remote origin of the local repository if you only want to get the current branch:
``` bash
git remote set-url origin [NEW_URL]
git push
```
Or use the mirror mode to get everything:
``` bash
# clone the old repo
git clone --mirror [OLD_URL]
cd [NEW_REPO_PATH]
# setup the new remote
git remote set-url origin [NEW_URL]
# push all to new repo
git push --mirror origin
```
⚠ Use the sourcehut url like git@git.sr.ht:~[username]/[repo] in order to read/write, the https one is for read only.

Note: If you don't need a project you can skip the creation part and directly change the set-url of the origin remote then push, sourcehut will automatically create the repository.

### Build pipeline

#### Prerequisites
Since it is about building webextension the main part is to get node / npm / yarn on the build machine.

I used nvm as the official recommandation from [NodeJS](https://nodejs.org/en/download) but [NodeSource](https://nodesource.com/products/distributions) offers package source for Linux distributions.  
I also tried [fnm](https://github.com/Schniz/fnm) as another official recommandation but it failed to install on first try and i didn't want to waste too much time investing it.

From the sourcehut build tutorials i found [this example of a build manifest using nvm](https://git.sr.ht/~xaffe/matrix-dokumentation/tree/master/.build.yml), so the basic `.build.yaml` (the build manifest for sourcehut) for installing node, npm and yarn could be like this:
``` yaml
image: archlinux
packages:
  - nvm
tasks:
- install: |
    # Avoid too verbose logs
    set +x

    # Init nvm
    . /usr/share/nvm/init-nvm.sh

    # Download and install Node.js
    nvm install --lts

    # Download and install Yarn if necessary
    corepack enable yarn
```
I also need to add this line to the install task, the `web-ext` package being the main tool to produce webextension:
``` yaml
    # Needed for the next tasks for webextension build and sign
    npm install --global web-ext
```
That is not needed if `web-ext` is a `dependencies` or `devDependencies` of the package.json.

Beware for [private repos](https://man.sr.ht/builds.sr.ht/private-repos.md), in order to checkout you have to:
- [generate a ssh key](https://git-scm.com/book/en/v2/Git-on-the-Server-Generating-Your-SSH-Public-Key) without a passphrase
- add the public part to your [sourcehut account](https://meta.sr.ht/keys)
- add the private to your [build secrets](https://builds.sr.ht/secrets)
- add the resulting uuid to your [build manifest](https://man.sr.ht/builds.sr.ht/manifest.md#secrets)

Resulting in lines like this in the build manifest:
```yaml
secrets:
  - [secret uuid]
```

#### build
This is simple enough and consist only to initialize nvm then call `web-ext build`:
```yaml
  - build: |
      set +x
      . /usr/share/nvm/init-nvm.sh
      nvm use current --silent
      cd [repo folder]
      web-ext build -s src # webextension source path
```
Or with yarn used to build with a script in the package.json, instead of calling `web-ext` directly:
```yaml
  - build: |
      set +x
      . /usr/share/nvm/init-nvm.sh
      nvm use current --silent
      cd [repo folder]
      yarn
      yarn build
```

#### sign
The sign part of the webextension requires the key and secret for the [AMO](https://addons.mozilla.org/) api.  
They can be generates on the [developper hub](https://addons.mozilla.org/en-US/developers/addon/api/key/) then added to the [sourcehut build secrets](https://builds.sr.ht/secrets) as a file with these properties :
- name: optional but could be the filename from the path property
- secret: content of key (issuer) or secret from AMO api
- type: file
- path: `~/firefox.api.key` for the key and `~/firefox.api.secret` for the secret
- mode: 400

Then for the build manifest part:
```yaml
  - sign: |
      set +x
      . /usr/share/nvm/init-nvm.sh
      nvm use current --silent
      cd [repo folder]
      web-ext sign -s src --api-key $(<~/firefox.api.key) --api-secret $(<~/firefox.api.secret)
```

Or with yarn used and `web-ext` in package.json dependency and not global:
```yaml
  - sign: |
      set +x
      . /usr/share/nvm/init-nvm.sh
      nvm use current --silent
      cd [repo folder]
      yarn exec web-ext sign -s build --api-key $(<~/firefox.api.key) --api-secret $(<~/firefox.api.secret)
```

#### Artifact
The signed webextension is available on the [AMO developper hub](https://addons.mozilla.org/en-US/developers/addons) but it is also possible to get it stored by sourcehut. Be aware that the artifact is uploaded only if the build succeeds, is stored for 90 days and should not be bigger than 1GiB.

The artifacts declaration is litteral and does not handle glob, `~` or shell code, the file path will not be interpreted.  
For signed webextension the filename contains the version so one solution is to rename the file.  
In the sign task:
```yaml
      mv web-ext-artifacts/[webextension name]-*.xpi web-ext-artifacts/[webextension name].xpi
```
And for the artifact declaration:
```yaml
artifacts:
  - [repo folder]/web-ext-artifacts/[webextension name].xpi
```


#### Sources:
- <https://man.sr.ht/>
- <https://man.sr.ht/builds.sr.ht/>
- <https://man.sr.ht/git.sr.ht/>
- <https://man.sr.ht/tutorials/builds.sr.ht/>
- <https://stackoverflow.com/questions/1484648/how-to-migrate-git-repository-from-one-server-to-a-new-one>
