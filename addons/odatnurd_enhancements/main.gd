@tool
extends EditorPlugin


# ------------------------------------------------------------------------------


# Preload the comment enhancement plugin and instantiate it.
var comments_plugin : RefCounted = preload("res://addons/odatnurd_enhancements/editor/comments.gd").new()

# Preload the image viewer plugin and instantiate it.
var img_preview_plugin: EditorInspectorPlugin = preload("res://addons/odatnurd_enhancements/image_preview/inspector_image_viewer.gd").new()

# Preload the plugin that extends the context menu for the file browser to allow
# for easy image viewing and instantiate it.
var img_preview_context_menu_plugin: EditorContextMenuPlugin = preload("res://addons/odatnurd_enhancements/image_preview/filesystem_context_menu.gd").new()


# ------------------------------------------------------------------------------


# Called exactly once when the user clicks "Enable" in Project Settings >
# Plugins. This is where one time setup goes.
func _enable_plugin() -> void:
    pass


# ------------------------------------------------------------------------------


# Called exactly once when the user clicks "Disable" in Project Settings >
# Plugins. This is where any cleanup of things we did in _enable_plugin() that
# should not persist should go.
func _disable_plugin() -> void:
    pass


# ------------------------------------------------------------------------------


# Gets launched when the editor launches, unless the plugin is not enabledl; in
# such a case enabling the plugin causes it to be launched.
func _enter_tree() -> void:
    # Set up our comment enhancements
    comments_plugin.setup()

    # Set up the image inspector plugin.
    add_inspector_plugin(img_preview_plugin)
    add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, img_preview_context_menu_plugin)


# ------------------------------------------------------------------------------


# Gets launched when the editor closes or the plugin is disabled.
func _exit_tree():
    remove_inspector_plugin(img_preview_plugin)
    remove_context_menu_plugin(img_preview_context_menu_plugin)


# ------------------------------------------------------------------------------


# Intercept all of the input events in the editor before they get processed so
# that we can see if our plugin wants to consume them or not.
func _input(event: InputEvent) -> void:
    # Delegate the input event down to the comments plugin script
    comments_plugin.handle_input(event)


# ------------------------------------------------------------------------------
