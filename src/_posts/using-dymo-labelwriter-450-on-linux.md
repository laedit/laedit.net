---
layout: post
title: Using a Dymo LabelWriter 450 on Linux
comments: true
tags: [dymo, printer, linux]
date: 2025-08-16
mastodon_id: 115039210438538230
---

I am mainly writing this for future me in case I need it again. I needed to print some labels with my Dymo LabelWriter 450 and haven't done this since switching to Linux. Even on Windows it wasn't that easy so I expected some hassle on linux.  
But it was a breeze :

First the driver installation, it appears that there is a package for that
```bash
sudo apt install printer-driver-dymo
```
Then connecting the printer and if you have lost the manual [Dymo has some articles on that](https://help.dymo.com).  
And the printer is already recognized by the system :  
[![Dymo LabelWriter 450 in the Printers window](/resources/using-dymo-labelwriter-450-on-linux/printers.png)](/resources/using-dymo-labelwriter-450-on-linux/printers.png)

So the last part was to edit the labels and print them. I could have use LibreOffice Writer which is already installed but prefered to check for a specialized software and thnks to [Garth Vander Houwen](https://medium.com/@garthvh/dymo-labelwriter-450-thermal-printer-ubuntu-setup-13362906a8ca) I discovered [gLabels](http://glabels.org).
It already have a template for some Dymo labels, I just needed to determine which was the one loaded in my printer. After some time of measuring a label and comparing to the properties of many templates I realized that the reference indicated by the `part #` of the product info was the reference indicated on the box of the labels :  
[![Dymo labels 99012 box](/resources/using-dymo-labelwriter-450-on-linux/99012.jpg)](/resources/using-dymo-labelwriter-450-on-linux/99012.jpg)
[![Dymo template for labels 99012 in gLabels](/resources/using-dymo-labelwriter-450-on-linux/glabels-properties.png)](/resources/using-dymo-labelwriter-450-on-linux/glabels-properties.png)

Just needed to edit my labels:  
[![gLabels edition window](/resources/using-dymo-labelwriter-450-on-linux/glabels-edit.png)](/resources/using-dymo-labelwriter-450-on-linux/glabels-edit.png)

And print it:  
[![gLabels print window](/resources/using-dymo-labelwriter-450-on-linux/glabels-print.png)](/resources/using-dymo-labelwriter-450-on-linux/glabels-print.png)  
[![gLabels printer selection window](/resources/using-dymo-labelwriter-450-on-linux/glabels-print-window.png)](/resources/using-dymo-labelwriter-450-on-linux/glabels-print-window.png)

#### Sources:
- <https://askubuntu.com/a/1272062/1734722>
- <https://medium.com/@garthvh/dymo-labelwriter-450-thermal-printer-ubuntu-setup-13362906a8ca>
- <https://github.com/j-evins/glabels-qt>
- <https://help.dymo.com/s/article/How-do-I-load-the-labels-on-the-spool-and-into-the-LabelWriter>
