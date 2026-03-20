@tool
extends RefCounted


# ------------------------------------------------------------------------------


# The path within Editor Settings > Shortcuts that our keyboard shortcut for
# reflowing comments lives.
const SHORTCUT_PATH = "odatnurd_enhancements/reflow_comment"

# The path within Editor Settings > General that our setting for enabling or
# disabling the auto comment feature lives.
const SETTING_AUTO_COMMENT = "plugin/odatnurd_enhancements/enable_auto_comment"

# A cached copy of the settings object and the keyboard shortcut that is used to
# trigger the reflow command.
var _settings: EditorSettings
var _reflow_shortcut: Shortcut


# ------------------------------------------------------------------------------


# Gets launched when the editor launches, unless the plugin is not enabledl; in
# such a case enabling the plugin causes it to be launched.
func setup() -> void:
    # Fetch the setting object.
    _settings = EditorInterface.get_editor_settings()

    # If we don't already have the setting that controls whether or not the
    # autocomment is enabled, then set the setting now, giving it an initial
    # value. This is the value that becomes the default.
    if not _settings.has_setting(SETTING_AUTO_COMMENT):
        _settings.set_setting(SETTING_AUTO_COMMENT, true)
        _settings.set_initial_value(SETTING_AUTO_COMMENT, true, true)

    # Give the editor information about the setting so that it knows how to
    # present it.
    _settings.add_property_info({
        "name": SETTING_AUTO_COMMENT,
        "type": TYPE_BOOL
    })

    # Now we eant to set up a default keybind for our reflow command, which
    # we are setting to Alt+q because Sublime.
    var default_shortcut := Shortcut.new()
    var default_event := InputEventKey.new()
    default_event.keycode = KEY_Q
    default_event.alt_pressed = true
    default_shortcut.events.append(default_event)

    # Register the keybind now; as far as I can tell, if there is no such
    # binding entry yet, this sets it and also makes it the default, but if the
    # value is there and the user changed it, this does not change anything at
    # all.
    #
    # This seems confusing and is not how the documentation reads, but that is
    # how it behaves, so meh?
    _settings.add_shortcut(SHORTCUT_PATH, default_shortcut)

    # Now, pull the reflow shortcut out; it might be the one we just created, or
    # it might be the one that the user has set up; either way, we want to keep
    # it locally so we can test against it.
    _reflow_shortcut = _settings.get_shortcut(SHORTCUT_PATH)


# ------------------------------------------------------------------------------


# Intercept all of the input events in the editor before they get processed so
# that we can see if our plugin wants to consume them or not.
func handle_input(event: InputEvent) -> void:
    # We only care about keyboard keys that are being pressed; all other input
    # events are not interesting to us.
    if not (event is InputEventKey and event.pressed):
        return

    # Get the owner of the focus to see what the user is interacting with; if
    # this is not the code editor, then we don't care about this key at all.
    var focus_owner := EditorInterface.get_base_control().get_viewport().gui_get_focus_owner()
    if not focus_owner is CodeEdit:
        return

    # We know that this is not just a control, it is an editor, so get a typed
    # version of it.
    var editor := focus_owner as CodeEdit

    # If we have a reflow shortcut and this event matches it, then dispatch to
    # that handler.
    if _reflow_shortcut != null and _reflow_shortcut.matches_event(event):
        return _handle_comment_reflow(editor)

    # If this was the enter key, then we might be inside of a comment, so if the
    # setting for reflowing comments is also turned on, dispatch.
    if event.keycode == KEY_ENTER and _settings.get_setting(SETTING_AUTO_COMMENT):
        return _handle_auto_comment(editor, event as InputEventKey)


# ------------------------------------------------------------------------------


## Given a comment, calculate what the comment prefix is (one or more hashes
## followed by 0 or more whitespace characters) and return that value back; this
## is what would be used to generate a new comment identical to the one
## provided.
func _get_comment_prefix(comment: String) -> String:
    var prefix_end := 0
    var comment_len := comment.length()

    # Skip ahead until we find the first character that is not a hash.
    while prefix_end < comment_len and comment[prefix_end] == '#':
        prefix_end += 1

    # Skip ahead until we find the first character that is not whitespace.
    while prefix_end < comment_len and (comment[prefix_end] == ' ' or comment[prefix_end] == '\t'):
        prefix_end += 1

    # Calculate the index now.
    return comment.substr(0, prefix_end)


# ------------------------------------------------------------------------------


## This handles our auto-comment feature, in which pressing enter causes the
## newline to be inserted but also we continue the comment onto the next line as
## well.
func _handle_auto_comment(editor: CodeEdit, event: InputEventKey) -> void:
    # The default in Godot for Ctrl+Enter is to insert a line break without
    # moving the cursor; here this means that we want to insert a newline
    # without continuing a possible comment, so in that case we adjust the event
    # to not include the ctrl key, then leave so that Godot will handle this as
    # it normally would.
    if event.ctrl_pressed:
        event.ctrl_pressed = false
        return

    # Get the current state of the cursor and the text on the line it occupies.
    # We also need the colunn that the caret is in and the location of the first
    # hash character within the line.
    var line_text := editor.get_line(editor.get_caret_line())
    var column := editor.get_caret_column()
    var hash_pos := line_text.find("#")

    # If there is not a hash on this line at all, or there is but the cursor is
    # positioned before it, then we don't need to anything; we are not inside of
    # a comment.
    if hash_pos == -1 or column <= hash_pos:
        return

    # Split the string into the part that comes before the hash we found and the
    # part that comes after it.
    var text_prefix := line_text.substr(0, hash_pos)
    var comment := line_text.substr(hash_pos)

    # Determine what the comment prefix should be; this tells us what kind of
    # comment to create.
    var prefix := _get_comment_prefix(comment)

    # Now check the text that comes before the comment character and, starting
    # from the start of the line, find the first thing that is not whitespace;
    # this will tell us how to start the next line.
    var first_non_ws := 0
    while first_non_ws < hash_pos and (text_prefix[first_non_ws] == ' ' or text_prefix[first_non_ws] == '\t'):
        first_non_ws += 1

    # If the first non-whitespace is the hash, then the text prior to us is
    # purely made of indent. Using this we can determine if we want to use the
    # actual text prefix of the line or not.
    #
    # This allows us to handle comments that are inline with code to only share
    # the indent of the following line.
    var is_pure_indent := (first_non_ws == hash_pos)
    var new_indent := text_prefix if is_pure_indent else text_prefix.substr(0, first_non_ws)

    # Now we can insert our newline character, the indent for the next line, and
    # our calculated comment prefix.
    editor.insert_text_at_caret("\n" + new_indent + prefix)

    # Mark that we have consumed the text so that the default handling does not
    # insert a second line.
    editor.get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------------


## Examine the cached editor settings to find the preferred wrap column to do
## word wrapping of reflowed comments at. This defaults to 80, but if there is a
## soft or hard column limit, they are used instead (in that order).
func _get_ruler_column() -> int:
    var ruler_col := 80
    if _settings.has_setting("text_editor/appearance/guidelines/line_length_guideline_soft_column"):
        ruler_col = _settings.get_setting("text_editor/appearance/guidelines/line_length_guideline_soft_column")
    elif _settings.has_setting("text_editor/appearance/guidelines/line_length_guideline_hard_column"):
        ruler_col = _settings.get_setting("text_editor/appearance/guidelines/line_length_guideline_hard_column")
    return ruler_col


# ------------------------------------------------------------------------------


## This scans up and down from the start line provided to find the bounds of the
## comment block that the cursor is currently inside of. This will consider only
## lines that contain the same style of comment (as defined by the comment
## prefix) as the line that the cursor is on.
##
## The search stops at any line that is either not a comment or has a different
## comment style.
func _find_comment_boundaries(editor: CodeEdit, start_line: int, text_prefix: String,
                              prefix: String, is_base_pure_indent: bool) -> Vector2i:
    var current_start := start_line
    var current_end := start_line

    # For our purposes, the number of hashes on a comment line is what makes it
    # part of the same comment, even if there is whitespace after it. So, grab
    # from what we were given just the number of hashes.
    var expected_hashes := prefix.strip_edges(false, true)

    # This inline function examines the text that it was given and determines if
    # it is part of the same comment block or not.
    #
    # A comment is part of the same block only if it is a line that is wholly a
    # comment and only if it has the same comment prefix and indenation as what
    # we were given (so # lines will *not* merge and wrap with adjacent ## lines
    # and nor will it merge indented comments that are adjacent and in the same
    # style).
    var is_part_of_block = func(text: String) -> bool:
        # Get the hash position; this can't be a comment if it does not have one.
        var h := text.find("#")
        if h == -1:
            return false

        # Get the text prior to the comment; if it is not the same, this is a
        # differently indentented potential comment; we don't wrap those either.
        var line_indent := text.substr(0, h)
        if line_indent != text_prefix:
            return false

        # If the indent is not wholly whitespace, then don't count it.
        for i in range(h):
            var c := line_indent[i]
            if c != ' ' and c != '\t':
                return false

        # Grab the body of the comment, and from that the prefix that preceeds
        # it. We also capture the comment hashes, irrespective of any whitespace
        # (assuming that it IS hashes).
        var body := text.substr(h)
        var line_prefix := _get_comment_prefix(body)
        var line_hashes := line_prefix.strip_edges(false, true)

        # We need this line to have the same comment style as what we were given
        # to test against.
        if line_hashes != expected_hashes:
            return false

        # This line is a part of the comment when it has the same prefix or is
        # an empty comment line that has only the hashes (in which case it is a
        # paragraph break).
        return line_prefix == prefix or body == line_hashes

    # If the line that we're on is a pure comment, then scan forwards and
    # backwards from it to find the bounds of all of the lines that have the
    # same comment style and are thus a part of it.
    if is_base_pure_indent:
        while current_start > 0:
            if is_part_of_block.call(editor.get_line(current_start - 1)):
                current_start -= 1
            else:
                break

        while current_end < editor.get_line_count() - 1:
            if is_part_of_block.call(editor.get_line(current_end + 1)):
                current_end += 1
            else:
                break

    # Return our "2-tuple" of values.
    return Vector2i(current_start, current_end)


# ------------------------------------------------------------------------------


## Given a start and end line and the common comment prefix that applies to all
## lines in the block, gather each comment and split it into words, applying a
## paragraph break at empty lines.
##
## The result is an array of paragraphs (represented themselves as an array of
## words) that were seen.
##
## Blank lines in the source blocks end up as empty arrays in the result so that
## we can keep the exact same spacing as we got coming in.
func _extract_paragraphs(editor: CodeEdit, start_line: int, end_line: int, prefix: String) -> Array:
    # A list of all of the paragraphs of text; each entry in the paragraphs
    # array is a list of the words within that paragraph so that we can reflow
    # things.
    #
    # A paragraph only terminates when we run out of comment OR when we hit a
    # comment line that is blank.
    var paragraphs := []
    var current_paragraph_words := PackedStringArray()

    # The prefix is going to be the number of hashes we care about and that we
    # matched when we gathered the paragraphs of text, so get a version of it
    # without any trailing space.
    var expected_hashes := prefix.strip_edges(false, true)

    # Scan over every line in the range that we were given, extracting the text
    # out.
    for i in range(start_line, end_line + 1):
        # Get this line, find the hash mark in it, and pull out the comment
        # portion of it
        var t := editor.get_line(i)
        var h := t.find("#")
        var body := t.substr(h)

        # Strip the hashes from the comment body, and then clean up whitespace;
        # this should give us the line of text that is the comment body at this
        # part (which may be an empty string, but that is ok.
        body = body.trim_prefix(expected_hashes)
        body = body.strip_edges()

        # If we ended up with some text, then grab the words out and add them to
        # the list of words in this paragraph.
        if body != "":
            current_paragraph_words.append_array(body.split(" ", false))
        else:
            # If we get here, there is a paragraph break. In that case, we
            # should put the list of words we just got for this paragraph
            # into the paragraphs array, and then start a new array.
            if current_paragraph_words.size() > 0:
                paragraphs.append(current_paragraph_words)
                current_paragraph_words = PackedStringArray()

            # Include an empty array to mark that we saw an empty line; this
            # ensures that we can reconstruct every blank line that we saw.
            paragraphs.append(PackedStringArray())

    # Finalize the last paragraph with any words we might have from the last
    # line we saw.
    if current_paragraph_words.size() > 0:
        paragraphs.append(current_paragraph_words)

    return paragraphs


# ------------------------------------------------------------------------------


## This reassembles the paragraph arrays from _extract_paragraphs() back into
## actual comment strings, returning back a single string that is meant to
## replace the entire area from which the paragraphs were extracted.
func _wrap_paragraphs(paragraphs: Array, prefix: String, text_prefix: String,
                      is_base_pure_indent: bool, ruler_col: int) -> String:

    # Get the tab size that is configured, in case we run into any.
    var tab_size := 4
    if _settings.has_setting("text_editor/behavior/indent/size"):
        tab_size = _settings.get_setting("text_editor/behavior/indent/size")

    # Figure how much physical space the leading indentation on all of the
    # comment lines is going to be.
    #
    # To do that we need to count the amount of indent in the lead in; this
    # counts 1 character for every space and the tab size for any tabs that we
    # find.
    var indent_width := 0
    var indent_pure := text_prefix if is_base_pure_indent else ""
    for i in range(indent_pure.length()):
        if indent_pure[i] == '\t':
            indent_width += tab_size
        else:
            indent_width += 1

    # Now we determine the width that we have available to us for the actual
    # content, which is the ruler position minus the indent minus the prefix
    # that we got.
    #
    # If this ends up too small, keep it to a minimum size for sanity. If this
    # hits, the user is already sad that their code is indented to what is
    # likely an unreadable level or they have a tiny, untenable ruler.
    var available_width := ruler_col - indent_width - prefix.length()
    if available_width < 20:
        available_width = 20

    var new_lines := PackedStringArray()

    # Check to see if this is a line that has an inline comment by seeing what
    # the prefix is.
    #
    # If there is code before the comment, then the first part of the wrap has
    # much less space than other lines because of what precedes it. Thus this
    # needs to be handled specially.
    var code_part := "" if is_base_pure_indent else text_prefix
    if code_part != "" and paragraphs.size() > 0 and paragraphs[0].size() > 0:
        # Calculate how much width the code part takes up; here a tab is the
        # configured size and everything else is just one.
        var code_w := 0
        for i in range(code_part.length()):
            if code_part[i] == '\t':
                code_w += tab_size
            else:
                code_w += 1

        # As above, calculate how much space is available on the first line, and
        # keep it to a sane limit.
        var first_line_avail := ruler_col - code_w - prefix.length()
        if first_line_avail < 20:
            first_line_avail = 20

        var first_line_words := PackedStringArray()
        var current_w := 0
        var first_para: PackedStringArray = paragraphs[0]

        # Pack words from the first paragraph into the first line until we hit
        # our limit for this line.
        var words_to_remove := 0
        for w in first_para:
            var wl = w.length()

            # If the word fits, we can add it; otherwise we should stop now.
            if first_line_words.size() == 0 or current_w + 1 + wl <= first_line_avail:
                first_line_words.append(w)
                current_w += wl if first_line_words.size() == 0 else (1 + wl)
                words_to_remove += 1
            else:
                break

        # Add this first line to the output array now.
        new_lines.append(code_part + prefix + " ".join(first_line_words))

        # We need to remove the words we just added to the first line from the
        # paragraph so that the next paragraph can continue from where we left
        # off here.
        var remaining_first_para := PackedStringArray()
        for i in range(words_to_remove, first_para.size()):
            remaining_first_para.append(first_para[i])
        paragraphs[0] = remaining_first_para

    # Loop through all of the seen paragraphs now, assembling lines.
    for p in paragraphs:
        # If this paragraph is empty, then we just need to insert the indent
        # and prefix; this is a marker that tells us that the source comment
        # had a paragraph break in it.
        if p.size() == 0:
            new_lines.append(indent_pure + prefix)
            continue

        # This is a standard paragraph, so we can grab out words to fit the line
        # width we have calculated.
        var current_words := PackedStringArray()
        var current_w := 0

        # Iterate over all of the words in the paragraph; as we go we put words
        # into the list of words, and count up their length; this lets us know
        # when it is time to split.
        for w in p:
            var wl = w.length()
            # The first word in the line; we don't care about length here
            # because a line must always have at least one word in it; we don't
            # split mid-word, ever.
            if current_words.size() == 0:
                current_words.append(w)
                current_w = wl

            # If this word fits on the current line, then we can add it in.
            elif current_w + 1 + wl <= available_width:
                current_words.append(w)
                current_w += 1 + wl

            # The current word is too long; in this case we need to append a
            # new line to the output consisting fo the index and all of the
            # words, and then we can clear the list and get ready to start a
            # new line.
            else:
                new_lines.append(indent_pure + prefix + " ".join(current_words))
                current_words.clear()
                current_words.append(w)
                current_w = wl

        # If any words are still left, then they go into the final line.
        if current_words.size() > 0:
            new_lines.append(indent_pure + prefix + " ".join(current_words))

    # For sanity, if this resulted in no paragraphs and there was no code part,
    # then just emit hashes.
    if paragraphs.size() == 0 and code_part == "":
        new_lines.append(indent_pure + prefix.strip_edges(false, true))

    # The final result is our list of lines, joined together.
    return "\n".join(new_lines)


# ------------------------------------------------------------------------------


## This handles our comment reflow feature, which finds all of the lines above
## and below the line that contains the caret that are purely comment, and then
## reflows them to match the inner ruler length.
func _handle_comment_reflow(editor: CodeEdit) -> void:
    # Grab the current line and column that the cursor is on.
    var line_num := editor.get_caret_line()
    var column := editor.get_caret_column()

    # Grab the text of the line and the position of the first hash that exists
    # within it.
    var line_text := editor.get_line(line_num)
    var hash_pos := line_text.find("#")

    # If the cursor is not currently in a comment, then we can leave.
    if hash_pos == -1 or column <= hash_pos:
        return

    # From our current line, gather the text prior to the first hash and the
    # text that follows; we then grab from the comment the prefix of hashes that
    # is being used to describe the comment.
    var text_prefix := line_text.substr(0, hash_pos)
    var comment := line_text.substr(hash_pos)
    var prefix := _get_comment_prefix(comment)

    # Find the first non-whitespace character in the text prefix, so that we
    # can determine whether or not it is fully whitespace or not. This allows
    # us to know if we are in an inline comment or not.
    var first_non_ws := 0
    while first_non_ws < hash_pos and (text_prefix[first_non_ws] == ' ' or text_prefix[first_non_ws] == '\t'):
        first_non_ws += 1

    var is_base_pure_indent := (first_non_ws == hash_pos)

    # Get our wrap column, then find the bounds of comments and extract those
    # paragraphs out, wrapping them at the desired boundary.
    var ruler_col := _get_ruler_column()
    var bounds := _find_comment_boundaries(editor, line_num, text_prefix, prefix, is_base_pure_indent)
    var paragraphs := _extract_paragraphs(editor, bounds.x, bounds.y, prefix)
    var replacement := _wrap_paragraphs(paragraphs, prefix, text_prefix, is_base_pure_indent, ruler_col)

    # We now have what we need to reflow the text. To do this we need to select
    # the text of the comments that we are reflowing and then insert text into
    # it to effect the replacement.
    #
    # This needs to be grouped together into a single undo operation.
    editor.begin_complex_operation()
    editor.select(bounds.x, 0, bounds.y, editor.get_line(bounds.y).length())
    editor.insert_text_at_caret(replacement)
    editor.end_complex_operation()

    # Tell Godot that we handled the input event.
    editor.get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------------
