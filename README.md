Goocanvas Image Viewer Demo
============================
(Uses Vala + GTK2 + Goocanvas.)

This program is an unfinished prototype of an image viewer (with thumbnails). 

It display images from a directory as Thumbnails, displays the full image when its thumbnail is clicked.

USAGE: ./goocanvas  [<directory name>]

When no directory is provided, the images from the current directory are displayed.

This program is not finished and has a number of known bugs.
They will not get corrected as I've started a completely new version using GTK3.

I'm making it available because it can help understand how to use GooCanvas.
The big problem with tutorials is that they only explain the basics, and an moderately complex
program goes far beyond their scope. On the other hand, real programs are usually so big and complex
that it's extremely difficult to extract the interesting part without a major learning curve.

 This program is short enough to be understood, but complex enough to show how to use Goocanvas in a
real program.

Sorry for the lack of comments. It was a very experimental project and I don't much add
comments to those (too many changes).

Major known bugs:
 - image not rotated
 - image resizing pb when resizing the window

