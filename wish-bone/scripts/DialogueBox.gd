extends CanvasLayer
class_name DialogueBox

signal finished
signal advanced(idx: int)

@onready var root_ui     : Control         = $RootUI
@onready var pad         : MarginContainer = $RootUI/Pad
@onready var text_box    : Control         = $RootUI/Pad/TextBox
@onready var inner_pad   : MarginContainer = $RootUI/Pad/TextBox/InnerPad
@onready var row         : HBoxContainer   = $RootUI/Pad/TextBox/InnerPad/Row
@onready var portrait_wr : Control         = $RootUI/Pad/TextBox/InnerPad/Row/PortraitWrap
@onready var portrait    : TextureRect     = $RootUI/Pad/TextBox/InnerPad/Row/PortraitWrap/Portrait
@onready var emoji_lbl   : Label           = $RootUI/Pad/TextBox/InnerPad/Row/PortraitWrap/Emoji
@onready var right_col   : VBoxContainer   = $RootUI/Pad/TextBox/InnerPad/Row/RightCol
@onready var header      : HBoxContainer   = $RootUI/Pad/TextBox/InnerPad/Row/RightCol/Header
@onready var name_lbl    : Label           = $RootUI/Pad/TextBox/InnerPad/Row/RightCol/Header/Name
@onready var mood_lbl    : Label           = $RootUI/Pad/TextBox/InnerPad/Row/RightCol/Header/MoodWord
@onready var dialogue    : RichTextLabel   = $RootUI/Pad/TextBox/InnerPad/Row/RightCol/Dialogue
@onready var hint_lbl    : Label           = $RootUI/Pad/TextBox/InnerPad/Hint

var lines: Array = []
var idx: int = -1
var typing := false
var cps := 60.0
var tween: Tween
var type_tween: Tween            # ✅ declare this
var panel_height := 280

func _enter_tree() -> void:
	if not InputMap.has_action("cutscene_advance"):
		InputMap.add_action("cutscene_advance")
		var ev := InputEventKey.new()
		ev.keycode = KEY_X
		InputMap.action_add_event("cutscene_advance", ev)
	if not InputMap.has_action("cutscene_skip"):
		InputMap.add_action("cutscene_skip")
		var ev2 := InputEventKey.new()
		ev2.keycode = KEY_ESCAPE
		InputMap.action_add_event("cutscene_skip", ev2)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_enforce_layout()
	hint_lbl.modulate.a = 0.0

func _enforce_layout() -> void:
	root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_box.custom_minimum_size = Vector2(0, panel_height)
	text_box.size_flags_horizontal = Control.SIZE_FILL
	text_box.size_flags_vertical   = Control.SIZE_SHRINK_END
	if "clip_contents" in text_box:
		text_box.clip_contents = true

	inner_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_pad.add_theme_constant_override("margin_left", 24)
	inner_pad.add_theme_constant_override("margin_right", 24)
	inner_pad.add_theme_constant_override("margin_top", 24)
	inner_pad.add_theme_constant_override("margin_bottom", 24)

	row.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	row.size_flags_vertical   = Control.SIZE_FILL
	if row.has_method("set_vertical_alignment"):
		row.set_vertical_alignment(1)
	row.add_theme_constant_override("separation", 20)

	portrait_wr.custom_minimum_size = Vector2(256, 256)
	portrait_wr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_wr.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode  = TextureRect.EXPAND_FIT_WIDTH

	emoji_lbl.anchor_left = 1.0; emoji_lbl.anchor_right = 1.0
	emoji_lbl.anchor_top  = 0.0; emoji_lbl.anchor_bottom = 0.0
	emoji_lbl.offset_left = -28; emoji_lbl.offset_top = 12

	right_col.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	right_col.size_flags_vertical   = Control.SIZE_FILL
	right_col.add_theme_constant_override("separation", 8)

	dialogue.bbcode_enabled = true
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue.fit_content = false
	dialogue.scroll_active = false
	dialogue.custom_minimum_size = Vector2(0, 140)
	dialogue.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	dialogue.size_flags_vertical   = Control.SIZE_FILL

func play(_lines: Array) -> void:
	lines = _lines
	idx = -1
	_advance()  # show first entry immediately

func _advance() -> void:
	# If it's still typing, finish instantly
	if typing:
		if type_tween and type_tween.is_running():
			type_tween.kill()
		dialogue.visible_ratio = 1.0
		typing = false
		_hint(true)
		return

	# Next line
	idx += 1
	if idx >= lines.size():
		finished.emit()
		queue_free()
		return

	_hint(false)
	_show(lines[idx])
	advanced.emit(idx)

func _show(line: Dictionary) -> void:
	# Header (instant)
	name_lbl.text = str(line.get("speaker", ""))
	var mood_word := str(line.get("mood_word", "")).strip_edges()
	mood_lbl.text = "" if mood_word.is_empty() else "[" + mood_word + "]"
	emoji_lbl.text = str(line.get("mood", ""))

	# Portrait
	var p := str(line.get("portrait_path", ""))
	if p != "" and FileAccess.file_exists(p):
		portrait.texture = load(p) as Texture2D
	else:
		portrait.texture = null

	# Text + typewriter via visible_ratio
	dialogue.text = str(line.get("text", ""))

	# Kill any previous tween
	if type_tween and type_tween.is_running():
		type_tween.kill()

	# Reset and tween 0 → 1
	dialogue.visible_ratio = 0.0
	var total := max(1, dialogue.get_total_character_count())
	var duration := max(0.05, float(total) / cps)  # cps = chars/sec feel

	typing = true
	type_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	type_tween.tween_property(dialogue, "visible_ratio", 1.0, duration)
	type_tween.finished.connect(func():
		typing = false
		_hint(true)
	)

func _input(e: InputEvent) -> void:
	# One-shot per key press
	if e is InputEventKey and e.pressed and not e.echo:
		if e.is_action_pressed("cutscene_advance"):
			_advance()
		elif e.is_action_pressed("cutscene_skip"):
			finished.emit()
			queue_free()

func _hint(show: bool) -> void:
	if tween and tween.is_running(): tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if show:
		hint_lbl.scale = Vector2.ONE
		hint_lbl.modulate.a = 0.0
		tween.tween_property(hint_lbl, "modulate:a", 1.0, 0.18)
		tween.tween_property(hint_lbl, "scale", Vector2(1.05,1.05), 0.08)
		tween.tween_property(hint_lbl, "scale", Vector2.ONE, 0.08)
	else:
		tween.tween_property(hint_lbl, "modulate:a", 0.0, 0.12)
