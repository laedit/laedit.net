---
layout: post
title: Commit to GitHub with Octokit.net
comments: true
tags: [github, octokit-net]
date: 2016-11-12
tweet_id: 797456352268455936
---

#### GitHub api & Octokit.net

GitHub has an [API](https://developer.github.com/) which amongts many features, can handles commits directly.

[Octokit.net](https://github.com/octokit/octokit.net) is the .net declinaison of [octokit](https://octokit.github.io/), the official GitHub API client.  
You can add it to a project through [Nuget](https://www.nuget.org/packages/octokit).

And to use it you just have to instanciate a `GitHubClient` with a `ProductHeaderValue` describing your application:

```csharp
var github = new GitHubClient(new ProductHeaderValue("GithubCommitTest"));
```

After that you already have access to many operations, like accessing the data of a user:

```csharp
var user = await github.User.Get("laedit");
Console.WriteLine($"laedit have {user.PublicRepos} public repos");
```

But in order to commit you have to authenticate yourself, otherwise you can have a "not found" error.

#### Authentication

There are two ways of doing it, either with login/password or personal access token.  
I strongly recommand the personal access token since it has a limited scope and can be revoked easily at any time.

For that:

- go to your GitHub's [settings/tokens page](https://github.com/settings/tokens)
- clic on "Generate new token"
- check at least the "public_repo" scope since it is needed to commit on public repository

Once generated, you can use it in the GitHub client:

```csharp
github.Credentials = new Credentials("personal_access_token");
```

The code above is only an example, avoid to store your token directly in source code or in a Version Control System.{.warning}

#### One file / one line commit

The API allows to dome some one-line commits for operations on single file:

```csharp
// github variables
var owner = "laedit";
var repo = "CommitTest";
var branch = "master";

// create file
var createChangeSet = await github.Repository.Content.CreateFile(
                                owner,
                                repo,
                                "path/file.txt",
                                new CreateFileRequest("File creation",
                                                      "Hello World!",
                                                      branch));

// update file
var updateChangeSet = await github.Repository.Content.UpdateFile(
                                owner,
                                repo,
                                "path/file.txt",
                                new UpdateFileRequest("File update",
                                                      "Hello Universe!",
                                                      createChangeSet.Content.Sha,
                                                      branch));

// delete file
await github.Repository.Content.DeleteFile(
                                owner,
                                repo,
                                "path/file.txt",
                                new DeleteFileRequest("File deletion",
                                                      updateChangeSet.Content.Sha,
                                                      branch));
```

All content is automatically converted to base64, preventing to commit any file other than text, like an image.  
This limitation will be removed with PR [#1488](https://github.com/octokit/octokit.net/pull/1488).{.warning}

#### Full commit

But it is also possible to acces the whole [Git Data](https://developer.github.com/v3/git/) and create a more complex commit step by step.
So you have a precise control on the git database but it require more API calls.

For example if you want to add a new commit on top of the last commit if the master branch:

 1. Get the SHA of the latest commit of the master branch

```csharp
var headMasterRef = "heads/master";
// Get reference of master branch
var masterReference = await github.Git.Reference.Get(owner, repo, headMasterRef);
// Get the laster commit of this branch
var latestCommit = await github.Git.Commit.Get(owner, repo, masterReference.Object.Sha);
```

 2. Create the blob(s) corresponding to your file(s)

```csharp
// For image, get image content and convert it to base64
var imgBase64 = Convert.ToBase64String(File.ReadAllBytes("MyImage.jpg"));
// Create image blob
var imgBlob = new NewBlob { Encoding = EncodingType.Base64, Content = (imgBase64) };
var imgBlobRef = await github.Git.Blob.Create(owner, repo, imgBlob);
// Create text blob
var textBlob = new NewBlob { Encoding = EncodingType.Utf8, Content = "Hellow World!" };
var textBlobRef = await github.Git.Blob.Create(owner, repo, textBlob);
```

 3. Create a new tree with:
    - the SHA of the tree of the latest commit as base
    - items based on blob(s) or entirelly new

```csharp
// Create new Tree
var nt = new NewTree { BaseTree = latestCommit.Tree.Sha };
// Add items based on blobs
nt.Tree.Add(new NewTreeItem { Path = "MyImage.jpg", Mode = "100644", Type = TreeType.Blob, Sha = imgBlobRef.Sha });
nt.Tree.Add(new NewTreeItem { Path = "HelloW.txt", Mode = "100644", Type = TreeType.Blob, Sha = textBlobRef.Sha });

// Other way to add a text file directly
// less API call but the content is automatically converted to base64 so only text can be used
var newTreeItem = new NewTreeItem { Mode = "100644", Type = TreeType.Blob, Content = "Hello Universe!", Path = "HelloU.txt" };
nt.Tree.Add(newTreeItem);

var newTree = await github.Git.Tree.Create(owner, repo, nt);
```

 4. Create the commit with the SHAs of the tree and the reference of master branch

```csharp
// Create Commit
var newCommit = new NewCommit("Commit test with several files", newTree.Sha, masterReference.Object.Sha);
var commit = await github.Git.Commit.Create(owner, repo, newCommit);
```

 5. Update the reference of master branch with the SHA of the commit

```csharp
var headMasterRef = "heads/master";
// Update HEAD with the commit
await github.Git.Reference.Update(owner, repo, headMasterRef, new ReferenceUpdate(commit.Sha));
```

Once understood it is not quite complex and it allows to learn how Git works with commit creation.
