---
layout: post
title: migrating the old reader bookmark from addon sdk to webextensions
tags: [firefox addon SDK, webextensions]
---

[Here](https://github.com/laedit/the-old-reader-bookmark/compare/7ae5b664a477db4a65aab0ceb63698496c103583...ccf3eac7a37ef260e44cda7d3847cfe9bc55faf3) is the comparison of the commits pushed for the addon's migration.{.tldr}


### The Addon


[The Old Reader - Bookmark](https://addons.mozilla.org/en-US/firefox/addon/the-old-reader-bookmark/) is an addon wich add a button to easily add a page or a selection of the page to [The Old Reader](https://theoldreader.com) bookmarks.  
It is done with [Firefox Addon SDK](https://developer.mozilla.org/en-US/Add-ons/SDK), both high-level and low-level APIs.


### Preparation

First thing to do: read some [docs](https://developer.mozilla.org/en-US/Add-ons/WebExtensions) on [WebExtensions](https://wiki.mozilla.org/WebExtensions).

And a good thing to have is [`web-ext`](https://blog.mozilla.org/addons/2016/04/14/developing-extensions-with-web-ext-1-0/) (available on [GitHub](https://github.com/mozilla/web-ext)), which is a command line tool aiming to help running and debugging WebExtensions.  
It is available through `npm`:

```
npm install --global web-ext
```

In order to ease the process, I have created a small cmd file which will update `web-ext` if necessary and run it :

```
@echo off
:: update web-ext
call npm update -g web-ext

echo Exit Code is %errorlevel%
if "%ERRORLEVEL%" == "1" exit /B 1

:: run web-ext
if [%1]==[] (
    web-ext -s "src" run --firefox-binary "C:\Program Files\Firefox Developer Edition\firefox.exe"
)

if [%1]==[current] (
    web-ext -s "src" run --firefox-binary "C:\Program Files\Mozilla Firefox\firefox.exe"
)

if [%1]==[beta] (
    web-ext -s "src" run --firefox-binary "C:\Program Files (x86)\Mozilla Firefox Beta\firefox.exe"
)
```

`web-ext` is run against the `src` folder which contains the WebExtension source and launch Firefox Developer Edition by default but can launch the current or beta version with the right argument.


### Migration

For the detail, lets begin with the folder tree before:

```
|- data
|  |- oldreadericon-16.png
|  |- oldreadericon-32.png
|  +- oldreadericon-64.png
|
|- lib
|  +- main.js
|
|- locale
|  |- en-US.properties
|  +- fr-FR.properties
|
|- icon.png
|- icon64.png
+- package.json
```

And after:

```
|- _locales
|  |- en
|  |  +- messages.json (moved and migrated from en-US.properties)
|  +- fr
|     +- messages.json (moved and migrated from fr-FR.properties)
|
|- content_scripts
|  |- getSelection.js
|  +- postNewBookmark.js
|
|- icons (renamed from data)
|  |- oldreadericon-16.png
|  |- oldreadericon-32.png
|  |- oldreadericon-48.png (moved from icon.png)
|  +- oldreadericon-64.png
|
|- background-script.cs (moved and migrated from main.js)
+- manifest.json (migrated from package.json)
```

Nothing complicated, just some files moved except for three parts:

- localization
- manifest
- logic

#### localization

That was the easiest part:

- rename folder from `locale` to `_locales`
- create a subfolder fo each language (instead of the culture previously used)
- migrate each file from [properties](https://developer.mozilla.org/en-US/Add-ons/SDK/Tutorials/l10n) to [the new format in json](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/Internationalization)

Each entry must have a key which will be used in the extension and a `message` property which contains the translation. The `description` property isn't mandatory but could be useful.

``` json
{
  "theOldReaderSelfBookmarkMessage": {
    "message": "If you were to bookmark The Old Reader with The Old Reader then the universe will fold in on itself and become a very large black hole.",
    "description": "Message when the user want to bookmark the old reader itself"
  },
  "addonDescription": {
    "message": "Bookmark the current page or selection in The Old Reader (premium membership needed)",
    "description": "addon description"
  }
}
```

#### manifest

The manifest stay in json but the format change to be [close that the one used by Chrome](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/manifest.json).  
As you can see by comparing the old [`package.json`](https://github.com/laedit/the-old-reader-bookmark/blob/7ae5b664a477db4a65aab0ceb63698496c103583/src/package.json) with the new [`manifest.json`](https://github.com/laedit/the-old-reader-bookmark/blob/master/src/manifest.json), some properties are quite the same:

- the title is now the name
- the version doesn't move
- the description can use a translated message, you have to use the following pattern: `__MSG_messageKey__`

Some are new:

- the key [`manifest_version`](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/manifest.json/manifest_version) is mandatory, with the value `2` for now
- the [`default_locale`](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/manifest.json/default_locale) key is also mandatory if you have a `_locales` folder
- all icons are now defined in the manifest under the [`icons`](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/manifest.json/icons) key
- the [`applications`](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/manifest.json/applications) key with the `gecko` subkey is specific to firefox, it is used in my addon to define:
  - the minimal version of firefox supported
  - the addon id - you can see that I have suffixed it with `@jetpack`: the id must now contains a `@`, but the `jetpack` part could be replaced by anything at your like
- the [`persmissions`](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/manifest.json/permissions) allow to define the permissions needed by the addon. In my case I need the `activeTab` to get the url of the current tab, and `<all_urls>` to execute my addon on any website.
- the [`browser_action`](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/manifest.json/browser_action) defines a button on the browser's toolbar, with an icon and a title
- the [`background`](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/manifest.json/background) defines the background scripts and page which are loaded at the launch of the extension, generally they contains the logic of the extension

And some have disappear:

- I haven't find where to put the license information
- same for author

#### logic

The logic of the extension take place in the background script, but since WebExtensions support [e10s](https://wiki.mozilla.org/Electrolysis) all interactions with the IHM or current page must be injected through a [content script](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/Content_scripts), even an `alert(...)` for showing a small information.

So, there is 4 parts in my [old logic script](https://github.com/laedit/the-old-reader-bookmark/blob/7ae5b664a477db4a65aab0ceb63698496c103583/src/lib/main.js):

- toolbar button declaration, wich have been moved to the manifest.json
- show an alert if the current tab is on theoldreader.com
- get the selection of the current tab if any
- post the selection and the url of the current tab to the old reader in a new tab

For the alert I had to use the [`tabs.executeScript`](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/API/tabs/executeScript) method which allow to inject a code or a script in a tab:

``` js
if(/^http(?:s?)\:\/\/theoldreader\.com/i.test(tab.url))
{
    browser.tabs.executeScript({ code: "alert('" + chrome.i18n.getMessage("theOldReaderSelfBookmarkMessage") + "');" });
    return false;
}
```

You can also see the use of [`i18n.getMessage`](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/API/i18n/getMessage) to get a translated message from the locales.

After that, I inject the content of [`getSelection.js`](https://github.com/laedit/the-old-reader-bookmark/blob/ccf3eac7a37ef260e44cda7d3847cfe9bc55faf3/src/content_scripts/getSelection.js):

``` js
browser.tabs.executeScript({ file: "content_scripts/getSelection.js" }, postToOldReadBookmarks);
```

Which get the selection of the current tab and return it. The second parameter is a callback method which handle the return of the script execution, in my extension it is the 4th part which post the data to the old reader in a new tab.

``` js
function postToOldReadBookmarks(selections) {
    browser.tabs.create({ index: currentTabIndex + 1, url: "https://theoldreader.com/bookmarks/bookmark" }, function (tab) {
        browser.tabs.executeScript(tab.id, { file: "content_scripts/postNewBookmark.js" }, function () {
            chrome.tabs.sendMessage(tab.id, {url: currentTabUrl, html: selections});
        });
    });
}
```

With the Addon SDK it was possible to post directly the data to a new tab but with WebExtensions it is not (yet?) possible, instead I use a [form created in a content script](https://github.com/laedit/the-old-reader-bookmark/blob/ccf3eac7a37ef260e44cda7d3847cfe9bc55faf3/src/content_scripts/postNewBookmark.js).  
Due to some limitations and [bugs](https://bugzilla.mozilla.org/show_bug.cgi?id=1272890), I must inject the script to a 'real' page, not a `about:blank` page or one included in my extension.  
After that I use the [`tabs.sendMessage`](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/API/tabs/sendMessage) to pass the data to the script, which will inject it as hidden input value before submitting the form.

And all works!

### conclusion

Right now WebExtensions are still in development and even if Firefox 48 have brought the first stable release I prefer to wait until at least v49 (which fix some issues I have encontered) is out before publishing the update of my addon.  
Nevertheless WebExtensions are very promising and the shared APIs with chrome, opera and even edge is a big asset, I will have to test my extension on those!