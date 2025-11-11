extends Node

const DIALOGUE_SCENE: PackedScene = preload("res://ui/DialogueBox.tscn")
const CUTSCENE_PATH: String = "res://cutscenes/exposition.json"

func _ready() -> void:
	get_tree().paused = true

	var lines: Array = _load_json(CUTSCENE_PATH)
	if lines.is_empty():
		push_warning("Cutscene JSON empty or bad: %s" % CUTSCENE_PATH)
		get_tree().paused = false
		return

	var box: CanvasLayer = DIALOGUE_SCENE.instantiate() as CanvasLayer
	box.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(box)

	box.call("play", lines)
	await box.finished

	box.queue_free()
	get_tree().paused = false

func _load_json(path: String) -> Array:
	if !FileAccess.file_exists(path):
		return []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var txt: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(txt)
	return (parsed as Array) if typeof(parsed) == TYPE_ARRAY else []
