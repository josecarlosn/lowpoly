
extends CanvasLayer
class_name DialogueUI

signal advance_requested

@export_range(1.0, 120.0, 1.0) var characters_per_second: float = 38.0

@onready var name_label: Label = $Root/DialoguePanel/Margin/VBox/CharacterName
@onready var dialogue_text: RichTextLabel = $Root/DialoguePanel/Margin/VBox/DialogueText
@onready var continue_label: Label = $Root/DialoguePanel/Margin/VBox/ContinueLabel

var _typing: bool = false
var _elapsed: float = 0.0
var _full_text: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_dialogue()


func _process(delta: float) -> void:
	if not visible or not _typing:
		return

	_elapsed += delta

	var visible_count := int(_elapsed * characters_per_second)
	dialogue_text.visible_characters = mini(visible_count, _full_text.length())

	if dialogue_text.visible_characters >= _full_text.length():
		_finish_typing()


func open_dialogue() -> void:
	visible = true
	continue_label.visible = false


func close_dialogue() -> void:
	visible = false
	_typing = false
	_elapsed = 0.0
	_full_text = ""


func present_line(line: DialogueLine) -> void:
	if line == null:
		return

	name_label.text = line.character_name
	name_label.visible = not line.character_name.strip_edges().is_empty()

	_full_text = line.text
	dialogue_text.text = _full_text
	dialogue_text.visible_characters = 0

	_elapsed = 0.0
	_typing = not _full_text.is_empty()

	continue_label.visible = not _typing

	if not _typing:
		dialogue_text.visible_characters = -1


func is_typing() -> bool:
	return _typing


func reveal_current_text() -> void:
	if not _typing:
		return

	dialogue_text.visible_characters = -1
	_finish_typing()


func _finish_typing() -> void:
	_typing = false
	dialogue_text.visible_characters = -1
	continue_label.visible = true


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("primary") and not event.is_echo():
		advance_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			advance_requested.emit()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey:
		var key_event := event as InputEventKey

		if key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_SPACE]:
			advance_requested.emit()
			get_viewport().set_input_as_handled()
