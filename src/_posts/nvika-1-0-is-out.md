---
layout: post
title: NVika 1.0 is out
comments: true
tags: [nvika, projects]
date: 2016-10-01
third_libraries: [gifffer]
---

![nvika icon](/resources/nvika-1-0-is-out/nvika-icon.png) After a while, [NVika](https://github.com/laedit/vika) is finally out of beta.

#### What does it do

Parse analytics reports and show issues on console or send them to the current build server.

In action:
<img data-gifffer="/resources/nvika-1-0-is-out/NVika_cmd.gif" />

On [AppVeyor](https://www.appveyor.com/):
[![nvika on AppVeyor](/resources/nvika-1-0-is-out/nvika-appveyor.png)](/resources/nvika-1-0-is-out/nvika-appveyor.png)

> Hey, but isn't that something [SonarQube](http://www.sonarqube.org) kinda do?

Yes, and you can even say that SonarQube do much more.

But NVika has some advantages, since it isn't doing the analysis part it is smaller and simpler to use, you only need a command line.

And since it isn't implying a web server (at least for now) it can be used in pull request to enforce the quality standard of your project.

#### Links

NVika is available on:

- [GitHub](https://github.com/laedit/vika/releases): source and binaries
- [Chocolatey](https://chocolatey.org/packages/nvika): command line tool
- [Nuget](https://www.nuget.org/packages/nvika.msbuild): MSBuild target

#### Future

At first I was thinking about a website, to put the consolidated reports on.  It would have been accessible to anyone, with repo's settings only accessible by his owner on GitHub, ala [CodeCov](https://codecov.io/) or other tool integrated to GitHub.
But I don't think it is a good idea, since SonarQube already do that and pretty well.

Another idea is to add some integration to other tools: GitHub on pull requests, Slack, Gitter, others?  
But since all of them need a user authorization it can't be done only with a command line tool.

**What do you think?**