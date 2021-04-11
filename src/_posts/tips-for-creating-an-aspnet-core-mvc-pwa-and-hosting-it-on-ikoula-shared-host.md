---
layout: post
title: Tips for creating an ASP.NET Core MVC PWA and hosting it on Ikoula Shared Host
comments: true
tags: [PWA, ikoula, asp.net]
date: 2021-04-01
tweet_id: 
---

**Disclaimer**: This is not a precise how-to but merely some tips.{.info}

### Creating an ASP.NET Core MVC PWA

I recently created a personal app and I wanted to try to make a PWA from an ASP.NET Core MVC app.

So once the app done I wanted to add the PWA specific parts which consist of two things:
- a manifest which describe the application to browser, in order for them to propose the installation for example
- a service worker which is generally used to cache some or all parts of the application in order to allow an offline use

There is a convenient Nuget package [WebEssentials.AspNetCore.PWA](https://www.nuget.org/packages/WebEssentials.AspNetCore.PWA/) which appears to do the job well, but I wanted to things myself since it is my first PWA.

#### Manifest

So I added a [`manifest.webmanifest`](https://developer.mozilla.org/en-US/docs/Web/Manifest) in the `wwwroot` folder, but the uri was returning a 404.
I appears that the `UseStaticFiles` method only returns files for known content type.  
So I had to add the right content type with the following code in the `Startup.Configure`:
``` csharp
var provider = new FileExtensionContentTypeProvider();
provider.Mappings[".webmanifest"] = "application/manifest+json";
app.UseStaticFiles(new StaticFileOptions { ContentTypeProvider = provider});
```

#### Service worker

For the service worker, I added his registration through a dedicated script in order to avoid issue with the csp: default-src 'self' policy:
``` js
if ('serviceWorker' in navigator) {
    document.addEventListener('DOMContentLoaded', () => {
        try {
            navigator.serviceWorker.register('/serviceworker.js', { scope: '/' });
        } catch (e) {
            console.error('Error during service worker registration', e);
        }
    });
}
```
It is registered only if the browser supports it and after the dom has loaded to avoid any blocking during the page load.  
The log is minimal here, you have to adapt it to your log system.

After that I created the service worker script but was confronted with another issue: I use typescript and by default it doesn't include the webworkers types so I was having errors about unknown types like `ExtendableEvent` and `FetchEvent`.  
So I found the right [StackOverflow answer](https://stackoverflow.com/questions/56356655/structuring-a-typescript-project-with-workers), reorganized my scripts and used a multi-tsconfig configuration to have all base compiler options common and specialized `lib` by folder : `DOM` for the client-side scripts and `WebWorker` for the service worker.

But I still had errors about the export part:
``` js
declare var self: ServiceWorkerGlobalScope;
export {};
```
It was because for this app I only used scripts and not client-side app, so I had the typescript compiler `module` option set to `none`.  
So once again after having found the right solution (this time on [github](https://github.com/microsoft/TypeScript/issues/11781#issuecomment-785350836)) I used the following code:
``` js
const sw: ServiceWorkerGlobalScope & typeof globalThis = self as any
```
and replaced all `self` by `sw`.

And after that all was well!

### Hosting on a Ikoula shared host


#### Web deploy
I have a shared host at Ikoula and they use Plesk for that.  
I recently discovered that Plesk have an option to activate the web deploy publishing under the hosting settings.  
Once activated you have a link on your site's dashboard which allows you to download the web deploy publishing settings.  
The format is not the same that the "Import Profile" option expect in Visual Studio 2019, but you can create a new "Web Server (IIS) / Web Deploy" publish profile and copy the values from the file.

If you have an issue on certificate check, that can be resolved through the "Validate Connection" on the Connection page.

#### SQLite error
I use SQLite with Entity Framework for business and identity storage and after the app deployment I got this error:
> DllNotFoundException: Unable to load DLL 'e_sqlite3' or one of its dependencies: Access denied. (0x80070005 (E_ACCESSDENIED))

I don't know how that works, but it appears that the SQLite Entity Framework package need the write permission to the folder where the dll are.  
So just add it to the application pool group user and that's done!

#### Secrets
If you use [secrets](https://docs.microsoft.com/en-us/aspnet/core/security/app-secrets), it is recommended to use environment variables.  
But if you can't (at least I didn't find a way to set one on Plesk), how do you do?

Well I tried to copy the content of the `secrets.json` in the `appsettings.json` after the deployment but it is not practical since I use webdeploy and it need to restart the website (a touch of the `web.config` suffice).

So finally I just used my own `secrets.json` file, added it to the app configuration and ignored it through the `.gitignore` to avoid leaking secrets.  
It is not the best but at least that do the trick.

So here my few tips, don't hesitate to guide me to better ways!