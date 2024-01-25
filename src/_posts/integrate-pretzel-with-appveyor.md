---
layout: post
title: integrate pretzel with appveyor
tags: [pretzel, appveyor]
date: 2016-06-14
comments: true
---

[Pretzel](https://github.com/code52/pretzel) is a static web site generator, much like [Jekyll](http://jekyllrb.com) but in .net.  
So while Jekyll users can use TravisCI or directly GitHub pages to generate their website we don't have this possibility with Pretzel.

Luckily, [Appveyor](https://appveyor.com) provides the same features than TravisCI but in a Windows environment. And it is free, so you just have to create an account or login with your GitHub account.

Like travis, it is based on a yaml configuration file, named `appveyor.yml`, like the [one](https://github.com/laedit/laedit.net/blob/master/appveyor.yml) for my website.

#### Preparation

First, we need to install pretzel:

``` yaml
install:
  - choco install pretzel -y

cache:
  - C:\tools\Pretzel -> appveyor.yml
```

The `cache` instruction indicates appveyor to store in [cache](https://www.appveyor.com/docs/build-cache) the content of the `C:\tools\Pretzel` folder until the appveyor.yml is modified.

The installation folder of pretzel will soon be modified to comply to [Chocolatey](https://chocolatey.org) rules.{.warning}


#### Build

The `build_script` is simple: just run the `bake` command of pretzel on the site source.

``` yaml
build_script:
- C:\tools\Pretzel\pretzel bake src

artifacts:
- path: src/_site
  name: compiled_site
```

Since the pretzel folder is in the appveyor cache, we cannot use the pretzel exe from the PATH, we must use the full path.{.warning}

The `artifacts` instruction defines the files or folder you want to save after a build. You can access and download these files directly on the appveyor website.

#### Test

``` yaml
test: off
```

So I think this line is self-explanatory: no test at all. For now at least, I plan to add a link checker soon. And maybe some sort of integration tests, we'll see.

#### Deploy

Since this post I have set an [incremental FTP deploy]({% post_url Incremental-ftp-deploy-with-creep %}) with [creep](https://github.com/r3c/creep/).{.info}

So, now the goal is to deploy the artifact in a FTP server.  
You can also deploy it to GitHub, Azure and other, appveyor support quite a few [deployment supports](http://www.appveyor.com/docs/deployment).

``` yaml
before_deploy:
- ps: .\Clear-FtpDirectory.ps1

deploy:
- provider: FTP
  host: laedit.net
  protocol: ftp
  username: zlaeditn12713ne
  password:
    secure: eK/zCvZEGU6BcRfo1CoYnlrLD7SoyaUyOb3aIq8CkmQ=
  folder: /httpdocs/laedit
  application: src\compiled_site.zip
```

The `before_deploy` instruction run a powershell (indicated by the `ps:` prefix) which cleans the destination folder.  
I use powershell but you can use a [Fake](http://fsharp.github.io/FAKE/) or your favorite build helper if you prefer.

Then the `deploy` instruction list all the deploy informations:

 - provider type
 - FTP host
 - protocol used
 - username used
 - password encrypted by appveyor and only decrypted during build (and not accessible during PR build +1 for security)
 - destination folder
 - the artifact to deploy

And since there is no constraints to the deploy, it is executed at each commit.

#### Conclusion

You now know how to use pretzel and appveyor to build and publish your shiny static website  
You are just a commit away to your next post.