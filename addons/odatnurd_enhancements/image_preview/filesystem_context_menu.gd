@tool
extends EditorContextMenuPlugin


# ------------------------------------------------------------------------------


# Preload the scene that we are going to attach to the extension windows that
# we create for actually viewing the content of a resource.
const Viewer: PackedScene = preload("res://addons/odatnurd_enhancements/image_preview/viewer_window.tscn")


# ------------------------------------------------------------------------------


# This is invoked by the engine when a right-click context menu is about to
# open. THe menu is provided by the place where we are bound, which in this case
# is the file browser.
#
# If there is exactly one file selected and it has an image extension, then we
# add an item that will trigger a preview of the image.
func _popup_menu(paths: PackedStringArray) -> void:
    # Only try to preview when there is a single file selected so that we don't
    # blow up the universe.
    if paths.size() != 1:
        return

    # Get the extension of the file; if it appears to be one of the image formats
    # that Godot supports, thn we are good to go.
    var ext = paths[0].get_extension().to_lower()
    if ext in ["png", "jpg", "jpeg", "webp", "svg", "bmp"]:
        # Look up an icon for this, and then attach a context menu item. The
        # function will get passed the paths when it triggers.
        var icon := EditorInterface.get_editor_theme().get_icon("Zoom", "EditorIcons")
        add_context_menu_item("Preview Image", _on_preview_pressed, icon)


# ------------------------------------------------------------------------------


# Triggered when the user clicks "Preview" in the right-click menu.
# The engine passes the array of selected paths automatically.
func _on_preview_pressed(paths: PackedStringArray) -> void:
    # This should never be possible but just in case I do something stupid
    # later.
    if paths.size() != 1:
        return

    # Try to load the texture; if it works, previewit.
    var texture = load(paths[0]) as Texture2D
    if texture:
        var window: Window = Viewer.instantiate()
        window.preview(texture)


# ------------------------------------------------------------------------------
