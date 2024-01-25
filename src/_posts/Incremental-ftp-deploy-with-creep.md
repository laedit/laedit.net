---
layout: post
title: Incremental FTP deploy of a Pretzel site with Creep on AppVeyor
comments: true
tags: [creep, ftp, deploy, appveyor, pretzel]
date: 2016-10-30
---

In a [previous post]({% post_url integrate-pretzel-with-appveyor %}), I have described how [Pretzel](https://github.com/code52/pretzel) could be integrated with [AppVeyor](https://www.appveyor.com/) in order to generate and deploy a website.

In the *deploy* part, I was clearing up all the contents on the FTP through a powershell script and then upload everything at every commit.  
It can be fine at start, but as the site grows it can be very time consuming and prone to errors.

In order to fix that, I was searching for an incremental deploy tool which handle FTP (since I am limited with that by my hosting) and I came across [creep](https://github.com/r3c/creep):  
it is written in python, can deploy either from a git revision or files hashes and to local file system, FTP or SSH.

In my case I works with a generated site, which is not versioned in git so I will deploy the content of a folder by using files hashes for comparison, to a distant FTP.  
The site must be deployed only if the generation went well, and for security I will store the FTP user/password in AppVeyor secure environment variable.

So, first step, add the variables in `appveyor.yml`, install the necessary softwares and call the powershell script which will be generating and deploying the site:

``` yaml
environment:
  ftp_user:
    secure: replace_with_you_appveyor_encrypted_ftp_user
  ftp_password:
    secure: replace_with_you_appveyor_encrypted_ftp_password

install:
  - choco install pretzel -y
  - ps: $env:Path += ";C:\\Python35;C:\\Python35\\Scripts"
  - pip install creep

cache:
  - '%LOCALAPPDATA%\pip\Cache -> appveyor.yml'

build_script:
- ps: .\BakeAndDeploy.ps1

test: off

artifacts:
- path: src/_site
  name: compiled_site
```

The `PATH` is needed to call `pip`.  
The tests are off in order to not waiste time on it.  
The artifact part is needed only if you want to keep a backup of the generated site.  

And the second part, the powershell script `BakeAndDeploy.ps1` itself:

{% raw %}
``` powershell
C:\tools\Pretzel\pretzel bake src

if ($lastExitCode -ne 0)
{
    exit -1
}
else
{
    Write-Host "Starting deploy"
    $envConf = '{{""default"": {{""connection"": ""ftp://{0}:{1}@laedit.net""}}}}' -f $env:ftp_user, $env:ftp_password
    creep -e $envConf -d '{""source"": ""hash""}' -b src/_site -y

    if ($lastExitCode -ne 0)
    {
        exit -1
    }
}
```
{% endraw %}

The script starts by calling `pretzel bake` on the site's source, and if the generation went ok it call creep.  
That part is quite confuse because it is a JSON string in a powershell script, with mandatory double quotes for each property. You can also use two files (`.creep.env` and `.creep.def`) but since I was getting the ftp user/password from environment variable I did not want to have to write two files every time. And sadly creep doesn't support clean command line parameters for that [right now](https://github.com/r3c/creep/issues/4).  
`$envConf` is the creep environment configuration, which in this case define a unique connection to my FTP server, with the user/password from environment variables. It is passed through the `-e` switch.  
The creep definition configuration, with the `-d` switch state that even if the current directory is in a git repository, creep must use the files hashes as comparison method.  
The `-b` switch defines the base directory and `-y` always answer 'yes' to prompts, allowing a quiet execution.

And now, at each commit only the new or modified files will be deployed and not the entire site.

There is only one remaining minor issues: it is displayed as an [error in AppVeyor](https://ci.appveyor.com/project/laedit/laedit-net/build/1.0.45#L162) even if it works. It probably come from the way python writes in console.