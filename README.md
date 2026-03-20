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


## Comments

Pressing `enter` while the caret is inside of a comment should continue the
comment onto the next line. To avoid this and go to the next line regardless,
`ctrl+enter` will insert a blank line without continuing the comment.

In `Editor > Editor Settings > General > Plugin > Odatnurd Enhancements` there
is a setting that allows you to turn this functionality off should it not be
desirable; the setting is enabled by default.

In addition, in `Editor > Editor Settings > Shortcuts > Odatnurd Enhancements`
you can bind `reflow_comment` to a key  (the default is `alt+q`).

Pressing this key while inside of a comment will gather all of the preceding
and following comment lines that share the same prefix as the line the caret is
in and reflows them to fit within the defined ruler guidelines. Any lines in the
comment that are otherwise blank (contain only the comment header) are preserved
during the reflow to as to keep spacing properly set up.

The column used defaults to 80, but is set to either
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