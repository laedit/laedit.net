---
layout: post
title: Switching from Pretzel to Zola
comments: true
tags: [pretzel, zola, linux]
date: 2026-10-08
mastodon_id: 117404662924190240
---

Since I replaced Windows by PopOS on my desktop I am in a strange situation: I use [Pretzel](https://github.com/code52/pretzel) to generate this blog and my [reading list 🇫🇷](https://readinglist.laedit.net/) but it cannot work on Linux.  
So I finally decided to change it by one which does and it is [Zola](https://www.getzola.org/).

**Disclaimer**: This is not a precise how-to but more of a note to myself of changes and some tips.{.info}

Before landing with Zola I searched for a static site generator with the following criterias:

- easy install on desktop, on my current CI in [AppVeyor](https://appveyor.com/) which use Windows and on my future CI in [SourceHut](https://sourcehut.org/) which will use Linux
- supports liquid templating or approaching to avoid having to redo all pages
- many features or easily expandable

After [having](https://lunet.io/) [considered](https://www.statiq.dev/) [many](https://gohugo.io/) [engines](https://cobalt-org.github.io) ([and](https://adduce.vale.rocks/) [more](https://github.com/ZarehD/AspNetStatic)) I finally settled with **Zola**.  
It checks all the boxes, is well maintained and have a good [docs](https://www.getzola.org/documentation) and [forum](https://zola.discourse.group).

So I first went to migrate my reading list and this blog will be done... one day.

Here is some tips and the major changes I had to do.

### Tips

#### Debug
It is possible to display the content of a variable, for example for sub-sections:
```liquid
{%- raw -%}
{% for subsection in section.subsections %}
subsection: {{ subsection }}
{% endfor %}
{%- endraw -%}
```

Thanks to that I realized that `subsection` was only the name of the subsection and you have to load the object through:
``` liquid
{%- raw -%}
{% set fullSubsection = get_section(path=subsection) %}
subsection: {{ fullSubsection }}
{%- endraw -%}
```
And then I will have the details of the subsection.

### Changes

#### Date format

With pretzel / liquid I used the following to format date: 
``` liquid
{% raw %}{{ page.date | date: "%Y-%m-%d" }}{% endraw %}
```
In tera it is: 
``` liquid
{% raw %}{{ page.date | date(format="%Y-%m-%d") }}{% endraw %}
```
The format is based on [strftime](https://docs.rs/jiff/latest/jiff/fmt/strtime/index.html#conversion-specifications).  
No big change for basic formatting but if you want to have the date in plain word that is done with the locale parameter: 
``` liquid
{% raw %}{{ page.date | date(format="d MMMM y", locale="fr") }}{% endraw %}
```
Note that the format with locale is based on [UTS-35 datetime patterns](https://unicode.org/reports/tr35/tr35-dates.html#Date_Field_Symbol_Table).

#### Frontmatter
Even if Zola handles yaml frontmetter for compatibility the default is toml so I make that leap because for the frontmatter the changes are too much.  
In Pretzel the frontmatter is like a bag of properties, some known and some unknown but all aligned like this:
``` yaml
layout: post
title: "Des fleurs pour Algernon"
author: "Daniel Keyes"
isbn: 9782290032725
editor: J´ai Lu
```
In Zola the frontmatter is typed so there are the known and the other move to an `extra` property:
``` toml
template = "reading-details.html"
title = "Des fleurs pour Algernon"
date = "2015-10-05"
aliases = ["2015/10/05/des-fleurs-pour-algernon.html"]
[extra]
kind = "book"
author = "Daniel Keyes"
isbn = "9782290032725"
editor = "J´ai Lu"
```
Note that the `layout` in Pretzel become `template` in Zola. It can be defined in a section `_index.md` file to avoig having it in all posts.

#### Structure
By default Zola generates page `[slug].md` in url like `[slug]/index.html`, but before I had url like `[slug].html` instead.  
Zola doesn't have a native way to change the generation pattern (the creator doesn't like the `[slug].html` urls) but it provides a way to have a redirection through the `aliases` property as seen on the preceding paragraph: each entry in this property will generate an html page with a redirect through javascript and html to the `[slug]/index.html` url. This was sufficient to avoid breaking any links or bookmarks to this site.

I also had all my posts in the same folder so I took advantage of this migration to move them in separate folders, to keep the same urls based on date the new path is like this: `content/2015/10/05/des-fleurs-pour-algernon.md`.  
The `content` folder in Zola is where you keep all markdown files which will be transformed to html, and then there is one folder by date part: year, month and day. Zole considers each `content` subfolder as a section, like a collection of pages of the same theme, but it was not what I was after so I used the `transparent` property of each section (day, month, year) which allows pages to be moved backup up to the parent section so that the home page can get them all in once to list them.  
The only hiccup encountered was that since the home page is not a section it does not have a `sort_by` property and the sort of the pages has to be done manually like this:
``` liquid
{% raw %}section.pages | sort(attribute="date") | reverse{% endraw %}
```

#### Sources:
- <https://www.getzola.org/documentation>
- <https://keats.github.io/tera/>
- <https://github.com/Keats/tera/blob/master/MIGRATION.md>
- <https://github.com/Keats/tera/blob/master/tera-contrib/README.md>
- <https://zola.discourse.group>
- <https://eduardouribe.com/date-formatting-on-tera/>
- <https://doc.rust-lang.org/std/fmt/>
- <https://docs.rs/jiff/latest/jiff/fmt/strtime/index.html>
