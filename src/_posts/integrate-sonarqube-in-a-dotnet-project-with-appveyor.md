---
layout: post
title: integrate sonarqube in a .net project with appveyor
tags: [sonarqube, appveyor ,fake]
date: 2016-09-29
comments: true
---

### What is SonarQube

From their [site](http://www.sonarqube.org/):  
SonarQube is an open platform to manage code quality. As such, it covers the 7 axes of code quality:

- Architecture & design
- Duplications
- Unit tests
- Complexity
- Potential bugs
- Coding rules
- Comments

So basically with this you can be pretty sure that your code is good.
And since it is open source, you can download it and install a copy on your own server.
Or you can use the [instance](https://sonarqube.com) dedicated to open source projects.

### Add scan to build

SonarQube works with MSBuild for .net projects through the [Scanner for MSBuild](http://docs.sonarqube.org/display/SCAN/Analyzing+with+SonarQube+Scanner+for+MSBuild), which is available on [Chocolatey](https://chocolatey.org/packages/msbuild-sonarqube-runner). There is also an unofficial plugin for [F#](https://github.com/jmecsoftware/sonar-fsharp-plugin) but it isn't available on the public instance of sonarqube.

All following code examples will be in *classic* command line and in [FAKE](http://fsharp.github.io/FAKE/), which is a build automation system I use in my projects, like for [NVika](https://github.com/laedit/vika/blob/master/build/build.fsx).

#### Installation

Two ways to install it, either download it from the [SonarQube Scanner for MSBuild page](http://docs.sonarqube.org/display/SCAN/Analyzing+with+SonarQube+Scanner+for+MSBuild) or through Chocolatey:

``` PowerShell
choco install "msbuild-sonarqube-runner" -y
```

or with FAKE, which have a lot of helpers:

``` fsharp
"msbuild-sonarqube-runner" |> Choco.Install id
```

#### Scan

The scan must be started before the build then ended after the build:

**Begin:**

``` PowerShell
MSBuild.SonarQube.Runner.exe begin /k:"laedit:Vika" /n:"Vika" /v:"0.1.4" /d:sonar.host.url=https://sonarqube.com /d:sonar.login=[SonarToken]
```

Or with FAKE:

``` fsharp
SonarQube Begin (fun p ->
        {p with
             ToolsPath = "MSBuild.SonarQube.Runner.exe"
             Key = "laedit:Vika"
             Name = "Vika"
             Version = version
             Settings = [ "sonar.host.url=https://sonarqube.com"; "sonar.login=" + environVar "SonarQube_Token" ] })
```

Mandatory parameters:

- `/k` | `Key`: key of the project; Must be unique; Allowed characters are: letters, numbers, `-`, `_`, `.` and `:`, with at least one non-digit.
- `/n` | `Name`: name of the project; Displayed on the web interface.
- `/v` | `Version`: version of the project.
- `/d:sonar.host.url`: SonarQube server url; default: `http://localhost:9000`; must be set to `https://sonarqube.com` to use the SonarQube public instance.
- `/d:sonar.login`: your login or [authentication token](docs.sonarqube.org/display/SONAR/User+Token). If login is used, you must use the `sonar.password` with your password as well but this is highly unsecure.

`SonarQube_Token` is an [AppVeyor](https://www.appveyor.com/) [secure environment variable](https://www.appveyor.com/docs/build-configuration/#secure-variables) wich contains the SonarQube token. While not mandatory it is recommended to generate one by project scanned.

There is also a bunch of other [parameters available](http://docs.sonarqube.org/display/SONAR/Analysis+Parameters).

**Build** like usual, with msbuild for example:

``` PowerShell
"C:\Program Files (x86)\MSBuild\14.0\Bin\MSBuild.exe" /t:Rebuild
```

Or an helper:

``` fsharp
Target "BuildApp" (fun _ ->
    !! "src/NVika/NVika.csproj"
      |> MSBuildRelease buildResultDir "Build"
      |> Log "AppBuild-Output: "
)
```

Then the **end** part:

``` PowerShell
MSBuild.SonarQube.Runner.exe end /d:sonar.login=[SonarToken]
```

or with FAKE:

``` fsharp
SonarQube End (fun p ->
        {p with
             ToolsPath = "MSBuild.SonarQube.Runner.exe"
             Settings = [ "sonar.login=" + environVar "SonarQube_Token" ]
        })
```

Since all security related parameters aren't write to the disk, you have to pass them again to the end part. Meaning that if you have used `login` + `password` in begin you have to pass them both again in end.

**Note:** there is no need to create a project in the web interface, it is automatically created on the first analysis.

#### Frequency

It's up to you to determine the frequency of the SonarQube scans, but int order to avoid abuse of the SonarQube public instance and because a scan is not needed for every local build I choose to start one only on AppVeyor and for the original repository (not forks) because I use AppVeyor's [secure environment variables](https://www.appveyor.com/docs/build-configuration/#secure-variables):

``` fsharp
// check if the build is on AppVeyor and for the original repository
let isOriginalRepo = environVar "APPVEYOR_REPO_NAME" = "laedit/vika"
let isAppVeyorBuild = buildServer = AppVeyor

// build dependencies: SonarQube scan will be launched only if the condition is true
"Clean"
  ==> "RestorePackages"
  =?> ("BeginSonarQube", isAppVeyorBuild && isOriginalRepo)
  ==> "BuildApp"
  =?> ("EndSonarQube", isAppVeyorBuild && isOriginalRepo)
```

#### Additional settings

You might want to subscribe to [notifications](http://docs.sonarqube.org/display/SONAR/Notifications+-+Administration) in order to be aware of each new issues or changes of the quality gate status.


But if you use the [public instance](https://sonarqube.com), subscribe only for specific projects if you want to avoid getting spammed with notifications of all projects.

Also, even if SonarQube doesn't propose built-in badges, [shields](http://shields.io/) do, so you can add one to your project's ReadMe.

### Use SonarQube in Pull Request builds

SonarQube have a [GitHub](http://docs.sonarqube.org/display/PLUG/GitHub+Plugin), which can handle the pull request build without pushing the results to SonarQube.

You just have to add several parameters:

- `sonar.analysis.mode=preview`: avoid to send the results to the SonarQube instance
- `sonar.github.pullRequest=" + environVar "APPVEYOR_PULL_REQUEST_NUMBER"`: pull request number, here from AppVeyor
- `sonar.github.repository=laedit/vika`: identification of the repository with format <organisation/repo>
- `sonar.github.oauth=" + environVar "Sonar_PR_Token"`: GitHub personal access token, with the scopes `public_repo` (or `repo` for private repositories) and `repo:status` in order to update the PR status

In this example, `Sonar_PR_Token` is the GitHub token embedded as AppVeyor [secure environment variable](https://www.appveyor.com/docs/build-configuration/#secure-variables). They are not accessible from PRs, unless you check the "Enable secure variables in Pull Requests from the same repository only" box in General tab of your AppVeyor's repo settings.

Even if only PRs from the same repository will have access to the content of the secure environment variable, they can still be visible in the logs of your AppVeyor builds, so be careful.{.warning}

But if you still want to implement it, be sure to add these parameters only on PRs, for example with FAKE:

``` fsharp
let isPR = environVar "APPVEYOR_PULL_REQUEST_NUMBER" |> isNull |> not

Target "BeginSonarQube" (fun _ ->
    "msbuild-sonarqube-runner" |> Choco.Install id

let sonarSettings = match isPR with
                        | false -> [ "sonar.host.url=https://sonarqube.com"; "sonar.login=" + environVar "SonarQube_Token" ]
                        | true -> [
                                    "sonar.host.url=https://sonarqube.com";
                                    "sonar.login=" + environVar "SonarQube_Token";
                                    "sonar.analysis.mode=preview";
                                    "sonar.github.pullRequest=" + environVar "APPVEYOR_PULL_REQUEST_NUMBER";
                                    "sonar.github.repository=laedit/vika";
                                    "sonar.github.oauth=" + environVar "Sonar_PR_Token"
                                  ]

    SonarQube Begin (fun p ->
        {p with
             ToolsPath = "MSBuild.SonarQube.Runner.exe"
             Key = "laedit:Vika"
             Name = "Vika"
             Version = version
             Settings = sonarSettings })
)
```

### SonarLint

If you want to find issues before committing, you can use [SonarLint](http://www.sonarlint.org/), either in your favorite IDE or through [command line](http://www.sonarlint.org/commandline/).