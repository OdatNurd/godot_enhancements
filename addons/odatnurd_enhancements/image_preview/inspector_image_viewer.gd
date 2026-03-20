@tool
extends EditorInspectorPlugin


# ------------------------------------------------------------------------------


# Preload the scene that we are going to attach to the extension windows that
# we create for actually viewing the content of a resource.
const Viewer: PackedScene = preload("res://addons/odatnurd_enhancements/image_preview/viewer_window.tscn")


# ------------------------------------------------------------------------------


# Every time the inspector focuses on a new object it invokes this to see if it
# should run our parse function for this object or not. We only want to trigger
# for texture images.
func _can_handle(object: Object) -> bool:
    return object is Texture2D


# ------------------------------------------------------------------------------


# Called when the editor begins building the Inspector UI for the handled object.
# Custom controls added here appear at the very top of the Inspector panel.
func _parse_begin(object: Object) -> void:
    var btn = Button.new()
    btn.text = "Preview Image"
    btn.icon = EditorInterface.get_editor_theme().get_icon("Zoom", "EditorIcons")

    btn.pressed.connect(func():
        # Instantiate the full scene with all its UI nodes, and tell it to preview
        # the texture.
        var window: Window = Viewer.instantiate()
        window.preview(object)
    )

    add_custom_control(btn)


# ------------------------------------------------------------------------------
