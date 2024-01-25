---
layout: post
title: Automatically publish a webextension to Firefox, Edge and GitHub
comments: true
tags: [webextension, firefox, edge, github]
date: 2023-08-14
mastodon_id: 110887169472575116
---

I wanted to automatically publish my webextension [New Tab - Moment](https://github.com/laedit/new-tab-moment) for some time but the lack of possibilities to specify the release notes has stopped me so far.

But there is now a new [api on mozilla's addons](https://addons-server.readthedocs.io/en/latest/topics/api/addons.html) which provides an endpoint for that, despite it being still not frozen and can change at any time.  

So after some thinking, [trials](https://github.com/mozilla/web-ext/issues/2686) and [errors](https://github.com/mozilla/web-ext/issues/2691) I have now the following system:

- The release notes are in the [Keep a changelog](https://keepachangelog.com) format
- A release Firefox action will:
  - build the webextension for firefox and edge and outputs two zips, one for each browser
  - extract the latest release notes
  - sign and publish the firefox zip along with the release notes on [AMO](https://addons.mozilla.org/)
  - download the resulting .xpi file
- A release GitHub action will create a GitHub release with the release notes, the zips and the xpi files
- A release Edge action will upload the edge zip to [Microsoft Partner Center Edge dashboard](https://partner.microsoft.com/en-us/dashboard/microsoftedge/overview) as a draft and submit it for publication

![Release schema](/resources/automatically-publish-webextension-to-firefox-edge-and-github/Release-schema.png)

And now for the details.

The following scripts are for GitHub actions but can easily be ported to another system, like the one from [Sourcehut](https://sourcehut.org/) for example.  
They also presume that the webextension has been created on each browser store hence they only do an update.{.info}

I use some external actions in these jobs and since they are still [not immutable](https://github.com/github/roadmap/issues/592) I reviewed the source code before trusting them with sensitive secrets, but I specify the commit I reviewed in the `uses` instead of a version to be sure I will use the exact code I have validated.  
That said it is always preferable to trust no one with your secrets and if possible write the code that uses them.{.warning}

### Release to Firefox
First the build is done through a shared action, used for a build workflow triggered on pushes and pull requests, and by the release workflow triggered on tags.  
It only call the `build` and `package` scripts of my `package.json` then gets the version number from the generated firefox zip to rename the firefox and edge zips and upload them as artifacts:

```yml
- run: |
    yarn build
    yarn package
    filename=`ls web-ext-artifacts/firefox/new_tab_-_moment-*.zip | head`
    versionZip=${filename##*-}
    version=${versionZip%.*}
    cp web-ext-artifacts/firefox/new_tab_-_moment-$version.zip web-ext-artifacts/new_tab_-_moment-$version.firefox.zip
    cp web-ext-artifacts/edge/new_tab_-_moment-$version.zip web-ext-artifacts/new_tab_-_moment-$version.edge.zip
  shell: bash

- uses: actions/upload-artifact@v3
  with:
    path: web-ext-artifacts/new_tab_-_moment-*.zip
    if-no-files-found: error
```

The `build` script is in charge to:
- transpile all typescript files to a `build/base` folder
- copy all other files (html, css, woff2, png) to the same `build/base` folder
- for each browser it will create a specific folder `build/{browser}`
- copy all the files from `build/base` to each browser folder
- then create the specific manifest for each browser since some properties aren't supported by all
For the details I leave you to my "to be improved" [package.json](https://github.com/laedit/new-tab-moment/blob/master/package.json).

After that the `package` script calls [`web-ext build`](https://extensionworkshop.com/documentation/develop/web-ext-command-reference/#web-ext-build) and [`web-ext lint`](https://extensionworkshop.com/documentation/develop/web-ext-command-reference/#web-ext-lint) for each browser folder.

After the build, the release to Firefox action creates the version metadata containing the release notes then signs the webextension on the Mozilla's addons website and finally uploads the resulting .xpi on the build's artefacts:
{% raw %}
```yml
  - name: Extract release notes
    id: extract-release-notes
    uses: ffurrer2/extract-release-notes@4db7ff8e9cc8a442ab103fd3ddfaebd0f8f36e4c

  - name: Create version metadata
    run: |
        release='${{ steps.extract-release-notes.outputs.release_notes }}'
        cat <<EOF > ./version-metadata.json
        {
          "version": {
            "release_notes": {
              "en-US": $(echo "${release//### }" | jq -sR .)
            }
          }
        }
        EOF

  - run: yarn web-ext sign --api-key ${{ secrets.AMO_ISSUER }} --api-secret ${{ secrets.AMO_SECRET }} --use-submission-api --channel=listed --source-dir build/firefox --amo-metadata ./version-metadata.json

  - uses: actions/upload-artifact@v3
    with:
      path: web-ext-artifacts/new_tab_moment-${{ github.ref_name }}.xpi
      if-no-files-found: error

  outputs:
    release_notes: ${{ steps.extract-release-notes.outputs.release_notes }}
```
{% endraw %}
The first two steps focuses on the version metadata: first the release notes of the last version is extracted thanks to [ffurrer2's github action](https://github.com/ffurrer2/extract-release-notes/) then it is inserted in the json file of the version metadata.

Then the [`web-ext sign`](https://extensionworkshop.com/documentation/develop/web-ext-command-reference/#web-ext-sign) command of the well-known webextension tool [web-ext](https://extensionworkshop.com/documentation/develop/getting-started-with-web-ext/) to upload the webextension to [AMO](https://addons.mozilla.org/), sign it and publish it if all went well.  
The argument `--amo-metadata [metadata file path]` (which has to be used with `--use-submission-api`) allows to specify the version metadata and thus the release notes.

### Release to GitHub
The GitHub release runs after the firefox one. It downloads the artifacts uploaded by the previous jobs and creates a new GitHub release with them and the release notes through the [softprops/action-gh-release](https://github.com/softprops/action-gh-release) action.
{% raw %}
```yml
release-github:
  needs: [release-firefox]
  runs-on: ubuntu-latest
  steps:
    - uses: actions/download-artifact@v3

    - name: Create Release
      uses: softprops/action-gh-release@de2c0eb89ae2a093876385947365aca7b0e5f844
      with:
        tag_name: ${{ github.ref }}
        name: ${{ github.ref_name }}
        body: ${{ needs.release-firefox.outputs.release_notes }}
        draft: false
        prerelease: false
        token: ${{ secrets.GITHUB_TOKEN }}
        files: |
          artifact/new_tab_-_moment-${{ github.ref_name }}.*.zip
          artifact/new_tab_moment-${{ github.ref_name }}.xpi
```
{% endraw %}
Note that a [GitHub access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) is needed.

### Release to Edge
The Edge release also runs after the firefox one, in parallel of the GitHub release. It downloads the artifacts uploaded by the previous jobs and submit the edge zip as a new version of the edge addon through the [wdzeng/edge-addon](https://github.com/wdzeng/edge-addon) action.
{% raw %}
```yml
release-edge:
  needs: [release-firefox]
  runs-on: ubuntu-latest
  steps:
    - uses: actions/download-artifact@v3

    - uses: wdzeng/edge-addon@b1ce0984067e0a0107065e0af237710906d94531
      with:
        product-id: ${{ secrets.EDGE_PRODUCT }}
        zip-path: artifact/new_tab_-_moment-${{ github.ref_name }}.edge.zip
        client-id: ${{ secrets.EDGE_CLIENT }}
        client-secret: ${{ secrets.EDGE_SECRET }}
        access-token-url: ${{ secrets.EDGE_TOKEN_URL }}
```
{% endraw %}
And here you go, it is not perfect but largely sufficient for my little addon and maybe yours.