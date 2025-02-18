---
layout: post
title: Webhook creation on SourceHut
comments: true
tags: [sourcehut, webhook]
date: 2025-02-18
---

I am now using [SourceHut](https://sourcehut.org/) to host the sources of some of my projects and wanted to deploy a static HTML page to my web host [Ikoula](https://www.ikoula.com).  
On my shared server, [Plesk](https://www.plesk.com/) is used to configure the websites and has a git option which allows to `git pull` from a source to the website folder for each `git push`, if the source emits a web hook.  
Sourcehut doesn't have a GUI to add de git web hook so you have to use their API. There is one [dedicated to git](https://man.sr.ht/git.sr.ht/api.md) but it is being replaced by the [GraphQL API one](https://man.sr.ht/git.sr.ht/graphql.md).

The git graphql api have their own [playground](https://git.sr.ht/graphql) but the [documentation](https://man.sr.ht/graphql.md) is global.  
To this day the api is still hunder development, it has the special version 0.0.0 which indicates that an API which is still undergoing its initial design work, and provides no stability guarantees whatsoever. {.warning}

So now for the web hook creation, there is a [CLI tool for sr.ht](https://git.sr.ht/~xenrox/hut) but I used [`curl`](https://curl.se/) to consume the graphql apis.  
First it is necessary to create a personal access token on <https://meta.sr.ht/oauth2> with at least read/write access to OBJECT and git.sr.ht/REPOSITORIES and read-only access to git.sr.ht/PROFILE.  
The token is valid for a year but can be revoked at any time.

Then to simplify the other actions, set the token in a variable:
```sh
oauth_token=<token>
```
And check that all is working by querying the version of the git graphql api:
``` sh
curl \
  --oauth2-bearer "$oauth_token" \
  -H 'Content-Type: application/json' \
  -d '{"query": "{ version { major, minor, patch } }"}' \
  https://git.sr.ht/query
```

If all is good, get the id of the git repository for which you want to add a web hook:
```sh
curl \
  --oauth2-bearer "$oauth_token" \
  -H 'Content-Type: application/json' \
  -d '{"query": "{ me { repositories { results { id, name } } } }"}' \
  https://git.sr.ht/query
```

And create a web hook:
```sh
curl \
  --oauth2-bearer "$oauth_token" \
  -H 'Content-Type: application/json' \
  -d '{"query": "mutation { createGitWebhook(config: { repositoryID: <repository_id> url: \"<webhook url>\" events:[GIT_POST_RECEIVE] query: \"query { webhook { uuid event date } }\" }) { id } }"}' \
  https://git.sr.ht/query
```
The query creates it with a post receive event, so the web hook will be called after all git process on the server have been handled but you can also use a pre receive event.  
The web hook has it's own graphql which defines the data send to the web hook. It allows to send only the necessary data.  
And in response you will have the id of the newly created web hook.

You can check if it has been added and get a sample payload if we want to test the web hook:
```sh
curl \
  --oauth2-bearer "$oauth_token" \
  -H 'Content-Type: application/json' \
  -d '{"query": "{ gitWebhooks(repositoryID: <repository_id>) { cursor results { id, events, url, sample(event: GIT_POST_RECEIVE) } } }"}' \
  https://git.sr.ht/query
```

And after some time and some `git push` you can check that it has been activated:
```sh
curl \
  --oauth2-bearer "$oauth_token" \
  -H 'Content-Type: application/json' \
  -d '{"query": "{ gitWebhooks(repositoryID: <repository_id>) { cursor results { id, events, url, deliveries() { results { uuid, date, responseStatus } } } } }"}' \
  https://git.sr.ht/query
```

Sources:
- <https://man.sr.ht/graphql.md>
- <https://git.sr.ht/graphql>
- <https://lists.sr.ht/~sircmpwn/sr.ht-discuss/%3Cd8def62a-22a9-e0ba-256c-6047b7de1fa8@agragps.com%3E>
