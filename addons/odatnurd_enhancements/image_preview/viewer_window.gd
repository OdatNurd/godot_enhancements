@tool
extends Window


# ------------------------------------------------------------------------------


# The path within Editor Settings > General that our setting for enabling or
# disabling the tile grid display lives.
const SETTING_SHOW_TILE_GRID = "plugin/odatnurd_enhancements/show_tile_grid"

# The path within Editor Settings > General that our setting for how big tiles
# are lives.
const SETTING_TILE_SIZE = "plugin/odatnurd_enhancements/tile_size"

# A cached copy of the settings object.
var _settings: EditorSettings


# ------------------------------------------------------------------------------


# This is the texture that is being inspected and that we are visualizing. This
# is a property so that when we set its value we can set our window title to the
# name of the resource.
#
# This falls back to a generic title if there is no texture or its path is
# empty.
var texture: Texture2D:
    set(value):
        texture = value
        if texture and not texture.resource_path.is_empty():
            title = texture.resource_path
        else:
            title = "Texture Viewer"

# In order to color sample, we need a cached copy of the texture image. The
# engine renders the Texture2D on its own but we can't access its pixels.
var image: Image

# Our scale multiplier; 1.0 is 100%.
var zoom: float = 1.0

# The translation offset from the center of the viewport, for when the user is
# dragging the image around to pan within it.
var pan: Vector2 = Vector2.ZERO

# Used for mouse interactions; we need to know if the user is currently dragging
# or not, and we keep a cached copy of the mouse position so that when we need
# to zoom and we want to do it relative to the mouse position, we know what
# that position was.
var is_dragging: bool = false
var mouse_pos: Vector2 = Vector2.ZERO

# The color of the pixel that is currently under the cursor; this is updated
# when the mouse moves over the texture.
var current_color: Color = Color.TRANSPARENT


# ------------------------------------------------------------------------------


# Called when the node enters the scene tree for the first time. We use this to
# hook up the signals from our UI scene and grab the dynamic editor icons.
func _ready():
    # Set up our Editor Settings.
    _settings = EditorInterface.get_editor_settings()

    # Include the setting for tile size, if it is not already present.
    if not _settings.has_setting(SETTING_TILE_SIZE):
        _settings.set_setting(SETTING_TILE_SIZE, 16)
        _settings.set_initial_value(SETTING_TILE_SIZE, 16, true)
        _settings.add_property_info({
            "name": SETTING_TILE_SIZE,
            "type": TYPE_INT
        })

    # Include the setting for whether or not to display the tile grid
    # if it is not already present.
    if not _settings.has_setting(SETTING_SHOW_TILE_GRID):
        _settings.set_setting(SETTING_SHOW_TILE_GRID, true)
        _settings.set_initial_value(SETTING_SHOW_TILE_GRID, true, true)
        _settings.add_property_info({
            "name": SETTING_SHOW_TILE_GRID,
            "type": TYPE_BOOL
        })

    # When the signal is received that there was a request to close the window,
    # discard the window.
    close_requested.connect(queue_free)

    # Fetch the standard editor icons for our buttons so they match the Godot UI.
    $TopPanel/TopHBox/ResetBtn.icon = EditorInterface.get_editor_theme().get_icon("ZoomReset", "EditorIcons")
    $TopPanel/TopHBox/SaveBtn.icon = EditorInterface.get_editor_theme().get_icon("Save", "EditorIcons")

    # Connect the UI signals to our functions.
    $TopPanel/TopHBox/FilterBtn.toggled.connect(func(toggled_on):
        $DrawControl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if toggled_on else CanvasItem.TEXTURE_FILTER_LINEAR
        $DrawControl.queue_redraw()
    )

    # When the toggle changes, alter the setting as well.
    $TopPanel/TopHBox/TileGridBtn.button_pressed = _settings.get_setting(SETTING_SHOW_TILE_GRID)
    $TopPanel/TopHBox/TileGridBtn.toggled.connect(func(toggled_on):
        _settings.set_setting(SETTING_SHOW_TILE_GRID, toggled_on)
        $DrawControl.queue_redraw()
    )

    $TopPanel/TopHBox/ResetBtn.pressed.connect(func():
        zoom = 1.0
        pan = Vector2.ZERO
        _update_ui()
    )

    $TopPanel/TopHBox/SaveBtn.pressed.connect(_on_save_pressed)
    $DrawControl.gui_input.connect(_on_gui_input)
    $DrawControl.draw.connect(_on_draw)


# ------------------------------------------------------------------------------


# Trigger the viewer to view the provided texture. This sets up, then attaches
# the view to the current editor instance and pops it up.
func preview(view_texture: Texture2D) -> void:
    texture = view_texture
    EditorInterface.get_base_control().add_child(self)
    popup_centered()


# ------------------------------------------------------------------------------


# This call intercepts all of the mouse events over the drawing control so that
# we can handle our panning, zooming, and click detection for the features of
# the viewer.
func _on_gui_input(event):
    # If the event is mouse motion, then we need to capture the position of the
    # mouse and potentially update the displayed coordinates.
    #
    # Also, if the mouse is currently being dragged, we also want to do some
    # panning as well.
    if event is InputEventMouseMotion:
        mouse_pos = event.position
        _update_coords()

        if is_dragging:
            pan += event.relative
            $DrawControl.queue_redraw()

    # If this is a mouse button, then we need to handle it as appropriate,
    # which also includes making sure we take care to only trigger when the
    # button is in an appropriate state.
    elif event is InputEventMouseButton:
        match event.button_index:
            MOUSE_BUTTON_WHEEL_UP:
                if event.pressed:
                    _change_zoom(1.1)
            MOUSE_BUTTON_WHEEL_DOWN:
                if event.pressed:
                    _change_zoom(0.9)
            MOUSE_BUTTON_RIGHT:
                if event.pressed:
                    _copy_color_to_clipboard()
            MOUSE_BUTTON_LEFT:
                # For the left mouse button, handle a double click specially;
                # otherwise, the left mouse button's press state tells us if we
                # are dragging or not.
                if event.pressed and event.double_click:
                    _handle_double_click(event.position)
                else:
                    is_dragging = event.pressed


# ------------------------------------------------------------------------------


# Handle double clicks inside of the image area. Any time a double click happens
# when we are not at 100%, we reset back to the 100% centered view. Otherwise,
# the double click's action depends on where the mouse cursor is and the current
# zoom.
#
# At 100% zoom, double clicking inside of the image jumps directly to 800%.
func _handle_double_click(pos: Vector2) -> void:
    # Any double click when we are not at 1:1 zoom causes us to directly zoom
    # back to 100% and center the image.
    if not is_equal_approx(zoom, 1.0):
        zoom = 1.0
        pan = Vector2.ZERO
    else:
        # If we are at 1:1 zoom and the double click happens within the image,
        # then zoom up to 800%. This allows for quickly getting in and out of
        # looking at a sprite without having to lean on the mouse wheel.
        var tex_size := texture.get_size() * zoom
        var tex_pos: Vector2 = ($DrawControl.size / 2.0) - (tex_size / 2.0) + pan
        var local_pos: Vector2 = (pos - tex_pos) / zoom

        # We only want to do this if the mouse is inside of the image.
        if Rect2(Vector2.ZERO, texture.get_size()).has_point(local_pos):
            zoom = 8.0
            var new_tex_size := texture.get_size() * zoom
            pan = (new_tex_size / 2.0) - (local_pos * zoom)

    # Ensure that the UI is updated.
    _update_ui()


# ------------------------------------------------------------------------------


# This handles changes in zoom by multiplying the current zoom level by the zoom
# factor that is given. In addition we also recalculate the panning offset so
# that the zoomed area is centered on the mouse cursor.
func _change_zoom(factor: float):
    var old_zoom = zoom
    zoom *= factor

    # We need to calculate the distance from the center and offset the pan by
    # the ratio of the change in the zoom in order to ensure that we end up
    # looking where we intended to.
    pan = mouse_pos - ($DrawControl.size / 2.0) - ( (mouse_pos - ($DrawControl.size / 2.0) - pan) * (zoom / old_zoom) )
    _update_ui()


# ------------------------------------------------------------------------------


# Perform updates to the user interface based on the current state of the values
# that control the display.
func _update_ui():
    $TopPanel/TopHBox/ZoomLabel.text = "Zoom: %d%%" % (zoom * 100)
    $DrawControl.queue_redraw()
    _update_coords()


# ------------------------------------------------------------------------------


# This maps the viewport mouse position to the local coordinate space of the
# texture that we're viewing and pulls out the color data for the pixel at that
# particular location.
#
# Once that is done, we update the user interface controls to display this info.
func _update_coords():
    # We can't do this if we don't have a texture to view.
    if not texture:
        return

    # If we have not yet cached the image that underlies the texture, do that
    # now; we keep the result of this so that we don't have to do it every
    # frame. The image is immutable so we're safe.
    if image == null:
        image = texture.get_image()

    # Determine where on the screen the texture is currently being displayed;
    # this depends on the size of the texture and it's zoom, and also needs to
    # take into account how the panning is set.
    var tex_size = texture.get_size() * zoom
    var tex_pos = ($DrawControl.size / 2.0) - (tex_size / 2.0) + pan

    # We need to get the actual image coordinates; note however that since we
    # are zoomed in, we need to invert the transform that was used so that we
    # get back to the actual pixel coordinate.
    var local_pos = (mouse_pos - tex_pos) / zoom
    var img_x = floor(local_pos.x)
    var img_y = floor(local_pos.y)

    # If the position is currently over the image, then we need to pull the
    # color and position out, and update the labels.
    if img_x >= 0 and img_x < texture.get_width() and img_y >= 0 and img_y < texture.get_height():
        # Coordinates are easy to display/
        $BotPanel/BotHBox/CoordLabel.text = "Pixel: %d, %d" % [img_x, img_y]

        # Grab the color and then display it
        current_color = image.get_pixel(img_x, img_y)
        var hex = "#" + current_color.to_html(true)

        $BotPanel/BotHBox/ColorLabel.text = "Color: %s | Color(%.3f, %.3f, %.3f, %.3f)" % [
            hex,
            current_color.r,
            current_color.g,
            current_color.b,
            current_color.a
        ]
    else:
        # The position is not over the cursor, so all of our display needs to be
        # hidden.
        $BotPanel/BotHBox/CoordLabel.text = "---"
        $BotPanel/BotHBox/ColorLabel.text = "Color: ---"
        current_color = Color.TRANSPARENT


# ------------------------------------------------------------------------------


# This handles copying the color that is currently under the mouse cursor to the
# clipboard. We ensure that what we are copying is a color constructor that can
# be placed directly into code, but which also has a trailing comment that has
# the hex code, for use in other circumstances.
#
# This gets us the best of both worlds.
func _copy_color_to_clipboard():
    # If we are not hovering over a valid pixel for grabbing a color, then we
    # can just leave. Hackily, we can tell if the mouse is not inside of the
    # image by checking the label text; this way we do not need to do the
    # calculation a second time.
    if current_color == Color.TRANSPARENT and $BotPanel/BotHBox/CoordLabel.text == "---":
        return

    # Construct the strings.
    var hex = "#" + current_color.to_html(true)
    var constructor = "Color(%.3f, %.3f, %.3f, %.3f) # %s" % [
        current_color.r,
        current_color.g,
        current_color.b,
        current_color.a,
        hex
    ]

    # Copy the text to the clipboard.
    DisplayServer.clipboard_set(constructor)

    # Use a simple modulation tween to visualize to the user that the text has
    # been copied by adjusting the color label's color temporarily.
    var tween = create_tween()
    $BotPanel/BotHBox/ColorLabel.modulate = Color.GREEN
    tween.tween_property($BotPanel/BotHBox/ColorLabel, "modulate", Color.WHITE, 0.5)


# ------------------------------------------------------------------------------


# This handles the click on the button that is used to save the image. We use a
# file dialog to prompt the user, then capture the image inside of the window
# and write it out as a PNG file.
func _on_save_pressed():
    # Set up the file dialog, indicating that we are going to access the normal
    # filesystem, that we want to save a file, and offering the type of file
    # that is going to be saved.
    var fd = FileDialog.new()
    fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    fd.access = FileDialog.ACCESS_FILESYSTEM
    fd.add_filter("*.png", "PNG Image")
    fd.current_file = "view_export.png"
    fd.use_native_dialog = true

    # The dialog triggers a callback when a file is selected, so connect that to
    # our handler.
    fd.file_selected.connect(func(path: String):
        # We don't want our toolbars to show up in the screenshot, since that
        # will get in the way.
        $TopPanel.hide()
        $BotPanel.hide()

        # Yield a short bit to make sure that the UI is fully gone from the
        # screen now that we have turned it off. This seems to be a common
        # safety measure to ensure that the rendering is complete.
        await get_tree().process_frame
        await get_tree().process_frame

        # Pull out the raw data and then write it to disk at the selected path.
        var img = get_viewport().get_texture().get_image()
        img.save_png(path)

        # We can put the toolbars back now.
        # Restore toolbars.
        $TopPanel.show()
        $BotPanel.show()
    )

    # Add the dialog to the tree and then pop it up.
    add_child(fd)
    fd.popup_centered_ratio(0.5)


# ------------------------------------------------------------------------------


# This is the meat of our display and handles all of the rendering of the
# texture inside of the window.
func _on_draw():
    # Can't display anything if there is no texture./
    if not texture:
        return

    # We need to calculate how big the image is based on the zoom, and determine
    # where the center is; this also needs to take the pan into account since
    # that bumps the center position.
    var tex_size = texture.get_size() * zoom
    var tex_pos = ($DrawControl.size / 2.0) - (tex_size / 2.0) + pan

    # Draw the image, and then surround it with a faint bounding box. For
    # sprite sheets this allows us to see the actual bounds of the image.
    $DrawControl.draw_texture_rect(texture, Rect2(tex_pos, tex_size), false)
    $DrawControl.draw_rect(Rect2(tex_pos, tex_size), Color(1, 1, 1, 0.3), false, 1.0)

    # If we are zoomed in enough, then we also want to display some grid lines.
    # However since this can make the display a little busy, this only happens
    # when the zoom is at least 800%; otherwise there might be too many
    # grid lines to display.
    if $DrawControl.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and zoom >= 8.0:
        var grid_color = Color(1, 1, 1, 0.15)

        # Draw in our vertical lines
        for x in range(texture.get_width() + 1):
            var x_pos = tex_pos.x + (x * zoom)
            $DrawControl.draw_line(Vector2(x_pos, tex_pos.y), Vector2(x_pos, tex_pos.y + tex_size.y), grid_color)

        # Now we can draw the horizontals.
        for y in range(texture.get_height() + 1):
            var y_pos = tex_pos.y + (y * zoom)
            $DrawControl.draw_line(Vector2(tex_pos.x, y_pos), Vector2(tex_pos.x + tex_size.x, y_pos), grid_color)

    # Should we be drawing the tile grid?
    if _settings.get_setting(SETTING_SHOW_TILE_GRID):
        var tile_size: int = _settings.get_setting(SETTING_TILE_SIZE)

        # Guard against a tile size of 0 or less to prevent infinite loops.
        if tile_size > 0:
            var tile_grid_color = Color(0, 1, 1, 0.5) # Distinct cyan color

            # Draw vertical tile lines
            for x in range(0, texture.get_width() + 1, tile_size):
                var x_pos = tex_pos.x + (x * zoom)
                $DrawControl.draw_line(Vector2(x_pos, tex_pos.y), Vector2(x_pos, tex_pos.y + tex_size.y), tile_grid_color)

            # Draw horizontal tile lines
            for y in range(0, texture.get_height() + 1, tile_size):
                var y_pos = tex_pos.y + (y * zoom)
                $DrawControl.draw_line(Vector2(tex_pos.x, y_pos), Vector2(tex_pos.x + tex_size.x, y_pos), tile_grid_color)


# ------------------------------------------------------------------------------
