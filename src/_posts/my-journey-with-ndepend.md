---
layout: post
title: My journey with NDepend
comments: true
tags: [ndepend, wpf, xaml]
date: 2017-05-16
tweet_id: 864376719960092672
---

**Disclaimer**: I was offered a 1 year NDepend pro license by [Patrick Smacchia](https://blog.ndepend.com/author/psmacchia/) (NDepend creator) so I could use it and share my experience if I wanted to.  
Since I was in the middle of the refactoring of a little personal WPF project, I though that this was the perfect time to test NDepend beyond the testing phase.{.info}

The project is a small WPF application which used only code behind, so I decided to refactor it to switch to MVVM and to change the design from [WPFSpark](https://github.com/ratishphilip/wpfspark) to [MahApps](http://mahapps.com/):

<img src="/resources/my-journey-with-ndepend/QIASI_old.png" title="before" alt="before" style="width: 350px;vertical-align:middle;"/>
<span style="font-size:50px;">➞</span>
<img src="/resources/my-journey-with-ndepend/QIASI_new.png" title="after" alt="before" style="width: 350px;vertical-align:middle;"/>

I started using NDepend during the refactoring so it passed some time before all was good, but here is my journey with NDepend.

### What is NDepend

I am not good at presenting things so you'd better go to their [site](http://www.ndepend.com/), but basically it is a static code analyzer which based on your assemblies and code coverage will bring you a ton a interesting information and metrics about your code.

### Installation

The installation is ultra easy: you only have to unzip a folder and launch Visual NDepend to validate the license.  
Then you can install the Visual Studio extension or another integration.

An installer and / or a Chocolatey package would be preferable but it does the job.

### Integration

NDepend have an extensive list of integrations:

- Visual NDepend
- NDepend Console
- Visual Studio
- TFS / VSTS
- SonarQube
- CruiseControl.NET
- FinalBuilder
- TeamCity
- Jenkins

I only used Visual NDepend, Visual Studio and the VSTS extension.

#### Visual NDepend

It is the standalone version of NDepend and propose all the functionalities of NDepend as wall as all the installation of Visual Studio extensions, the links to the docs, options, UserVoice and release notes:
![Visual NDepend start page](/resources/my-journey-with-ndepend/VisualNDepend_start.png)

It also take care of the updates, which are notified as windows notifications.

#### Visual Studio

The integration add a new NDepend menu which allow access to all windows / functionalities of NDepend.  
There is also a quick access through a round icon in the bottom right:
![NDepend Visual Studio quick access](/resources/my-journey-with-ndepend/NDepend_quick_access.png)

To create a new NDepend project attached to the current solution it is as simple as click on NDepend Menu / Attach new NDepend project to solution.  
Within a couple of seconds my solution of 9 projects (+1 for the WIX installer) have been analyzed and boy, I had work to do!
![NDepend dashboard](/resources/my-journey-with-ndepend/QIASI_NDepend_dashboard.png)

The integration with Visual Studio is beautiful but could be improved with roslyn integration: having the errors right on the code. It is a [topic on NDepend's UserVoice](https://ndepend.uservoice.com/forums/226344-ndepend-user-voice/suggestions/8973031-provide-auto-code-fixes-for-simple-issues).  
_**Edit**: it seems that it will be the next big thing of NDepend and has been announced during the [Build event](https://channel9.msdn.com/Events/Build/2017/B8019) (from 29:00)_  
Some windows are also oddly placed (the info tooltip appear too low and a part is invisible because it is below the screen).

#### VSTS

The extension is available on the [marketplace](https://marketplace.visualstudio.com/items?itemName=ndepend.ndependextension) and has a free 30 days trial.

It is also easy to [configure](http://www.ndepend.com/docs/vsts-integration-ndepend#HowToConfigureHub)

I have got some issues to make it work on my VSTS account but the support was responsive and a fix was issued within a day.

### Usage

Once the NDepend project properly configured, including the code coverage which needs some extra steps, you can run an analysis if one haven't been launched automatically after a project/solution build.

And now if your project is like mine, you are facing a long list of rules violated, the global status of your debt, a ton of information on your code (types, comments, coverage) and multiple ways to visualize it ([dependency graph](http://www.ndepend.com/docs/visual-studio-dependency-graph), [dependency matrix](http://www.ndepend.com/docs/dependency-structure-matrix-dsm), [metrics](http://www.ndepend.com/docs/treemap-visualization-of-code-metrics), [trends](http://www.ndepend.com/docs/trend-monitoring)).

So if you want to fix the debt, you just have to browse the rules and either choose to fix the code, or to adapt the rules to your project. You can deactivate some, or add some exceptions.

The good news is that all rules are stored in the `.ndproj` file, so every rule modification will be applicable for everyone running the project.  
And NDepend detect the modification of the `.ndproj` outside of the application (Visual NDepend or Visual Studio) and propose to reload it automatically. That is excellent but can lead to some freeze of Visual Studio.

One thing I loved is that unlike other static analyzer like Roslyn's analyzers or SonarQube, which I have used and propose only rules related directly to code and best practices, NDepend also provide some architectural level rules (Namespace dependency, project organization, assembly cohesion and such). That forced me to take some steps back and see the "big picture" of my project, which I didn't do in a while.  
That have allowed me to realized that most projects on the solution doesn't belong here but only on another. So I have reorganized entirely my solution and focus on the only project that matter.

### rules

I will not detail all the rules I have fixed on my project, there is too many and not all have a general interest. But there are some that I think are interesting or can be useful for every WPF / XAML project:

#### Avoid namespaces mutually dependent

A little refactoring of the designated classes have been sufficient.  
One was referencing types that it not needed to know to work, they were just passed to another class which need only object.  
The second was using a static property of the App class (in root namespace) to get the log file path, so I moved all log related code to a specialized class.

#### Methods should be declared static if possible

Cannot be applied to event handler bounded to a XAML window like `Loaded`. So the rule has been modified with an exception.


#### Avoid namespaces with few types

My project is small so it is normal that this rule raise a warning, but why is there the `XamlGeneratedNamespace` in it?  
As stated in his name, it is generated so I have no control over it. I think that this rule must ignore namespace which contains only generated types, so I modified the `Discard generated Namespaces from JustMyCode` which target only the **My** namespace of VB.NET to also target namespaces which contains only types with `GeneratedCode` attribute:

``` csharp
notmycode

// First gather assemblies written with VB.NET
let vbnetAssemblies = Application.Assemblies.Where(
   a => a.SourceDecls.Any(decl => decl.SourceFile.FileNameExtension.ToLower() == ".vb"))

// Then find the My namespace and its child namespaces.
let vbnetMyNamespaces = vbnetAssemblies.ChildNamespaces().Where(
   n => n.SimpleName == "My" ||
   n.ParentNamespaces.Any(nParent => nParent.SimpleName == "My"))

let generatedNamespaces = Application.Assemblies.ChildNamespaces().Where(
    n => n.ChildTypes.All(t => t.HasAttribute ("System.CodeDom.Compiler.GeneratedCodeAttribute")))

from n in vbnetMyNamespaces.Concat(generatedNamespaces)
select n
```

#### Instance fields naming convention / Fields should be declared as private

I had to specify names for some of my XAML elements and I choose the PascalCase naming convention, so these two rules was failing because the name wasn't corresponding to those of a field and because these XAML fields are generated internal be default.  
It is possible to change their modifier through the [`x:FieldModifier="private"` attribute](https://msdn.microsoft.com/en-us/library/aa970905(v=vs.110).aspx) but I considered that since it was part generated (everything but the name) it should not be considered as my code and modified the `Discard generated Fields from JustMyCode` rule:

``` csharp
notmycode
from f in Application.Fields where
  f.HasAttribute ("System.CodeDom.Compiler.GeneratedCodeAttribute".AllowNoMatch()) ||

  // Eliminate "components" generated in Windows Form Control context
  f.Name == "components" && f.ParentType.DeriveFrom("System.Windows.Forms.Control".AllowNoMatch()) ||
  // Eliminate XAML generated fields
  f.ParentType.Implement("System.Windows.Markup.IComponentConnector")
select f
```

`IComponentConnector` is XAML specific (WPF with this namespace, for UWP it is in `Window.UI.Xaml.Markup`) and is automatically implemented for every `Window`, `Page` and `UserControl`.

#### Avoid public methods not publicly visible / Methods that could have a lower visibility

All generated methods from properties of my ViewModels are marked but they need to be public for the XAML binding.

Rule modification to exclude all properties from classes which derive from my ViewModelBase:

``` csharp
&& !((m.IsPropertyGetter || m.IsPropertySetter) && m.ParentType.DeriveFrom("QIASI.Client.ViewModels.ViewModelBase"))
```

#### Potentially Dead Methods

Since XAML is not analyzed by NDepend, this rule list all properties used in XAML binding only. For now I haven't find a satisfying way to exclude them without avoiding the risk of false negative in the future.  
I looked at [`NDepend.API`](http://www.ndepend.com/api/webframe.html?NDepend.API_gettingstarted.html) but it doesn't seems like it is possible to add some information, only to manipulate information provided by NDepend analyzer.


#### Avoid the Singleton pattern

I also have modified this rule since it target only types with one static field of its parent type, but I wanted to also track the types which use their interface for the static field type.  
Here is the modified rule part:

``` csharp
let staticFieldInstances = t.StaticFields.WithFieldTypeIn(t.InterfacesImplemented.Concat(t))
where staticFieldInstances.Count() == 1
```

### Conclusion

Now my project is (almost) all green!
![NDepend dashboard](/resources/my-journey-with-ndepend/QIASI_NDepend_dashboard_after.png)

I loved use NDepend and will continue to use it.  
I particularly appreciate the flexibility permitted for the rules modification.  
It has some flaws, but the gain and possibilities are totally worth it.