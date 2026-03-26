# OdatNurd Enhancements

This is a simple plugin for Godot 4.6+ which adds a couple of features that stop
me from going mildly insane when using its editor:

* Pressing `enter` while inside of a comment continues that comment onto the
  next line in the file. This works inside of any comment, and the next line
  will infer the same comment prefix as the current line (`#`, `##`, with or
  without whitespace following it, etc).

* Provide the ability to re-flow a block comment so that it fits within a
  defined boundary in the editor.

* The context menu obtained by right clicking on an a Godot supported image in
  the sidebar will contain an item named `Preview Image` that will open the
  image in a preview window. Additionally, the inspector panel for an image
  includes a button above the preview.


## Settings

The plugin supports some simple settings and keybinds, which are all stored at:
 * `Editor > Editor Settings > General > Plugin > Odatnurd Enhancements` for
   settings
 * `Editor > Editor Settings > Shortcuts > Odatnurd Enhancements` for keyboard
   shortcuts.

See the below sections for the exciting content of these pages.


## Comment Enhancemeents

### Auto comment continuation

Pressing `enter` while the editing caret is inside of a comment will continue
the comment onto the next line. To avoid this and go to the next line
regardless, `ctrl+enter` will insert a blank line without continuing the
comment.

The `Enable Auto Comment` setting controls whether or not this is active; it is
turned on by default.


### Comment Reflow

Pressing the `reflow_comment` key (default is `alt+q`) while the caret is
inside of a comment will reflow that comment to fit without the bounds of the
designated column area.

This works by scanning backwards and forwards from the line containing the
comment that the caret is in, finding all comments that have the same comment
prefix (`#`, `##`, etc) and then reflowing them.

Comments that contain just white space and the comment prefix will be retained
as blank lines in the reflow, so that paragraph spacing is not lost.

The columne used to reflow defaults to `80` but is set to either
`Line Length Guideline Soft Column` or `Line Length Guideline Hard Column`
from `Editor Settings > General > Text Editor > Appearance`, depending on
whether or not those settings are set.


## Image Preview

The plugin adds a context menu item for images supported by Godot to the context
menu in the file browser, as well as a button in the Inspector , just above the
inspector's preview of the image.

Either option opens the image in a preview window. Controls are:

* `mouseup`/`mousedown` to alter the zoom level
* `double-left-click` inside of the image to jump directly to 800% zoom
* `double-left-click` anywhere while zoomed to reset the zoom back to 100%

If zoomed in to 800% or more, a grid will be displayed to outline the pixels
that are available in the image. The control in the header, `Pixel Art Mode`,
allows for a sharper view of pixel-art.

Hovering over the image will show you the color under the mouse cursor; a right
click will copy that color to the cliboard in the form:

```
Color(0.278, 0.549, 0.749, 1.000) # #478cbfff
```

This allows you to use it directly as a color value, or gather just the hex.

In addition, the plugin can display a tile grid as well on images, which is
controlled by the `Tile Size` and `Show Tile Grid` settings (the latter of
which also being available as a toggle control in the image previewer itself.)

When the tile grid is turned on, the tile grid is always displayed, even at low
zoom.
