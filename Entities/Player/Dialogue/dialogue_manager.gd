
extends Node
class_name DialogueManager

const DIALOGUE_UI_SCENE: PackedScene = preload("res://UI/Dialogue/dialogue_ui.tscn")

@export_range(1.0, 120.0, 1.0) var characters_per_second: float = 38.0

var is_dialogue_active: bool = false
var waiting_for_interaction_release: bool = false

var current_dialogue: DialogueData
var current_line_index: int = -1

var _previous_can_move: bool = true
var _previous_can_pause: bool = true
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

var _dialogue_ui: DialogueUI
var _player: Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = get_parent() as Player

	if not is_instance_valid(_player):
		push_error("DialogueManager precisa ser filho direto do Player.")
		set_process(false)
		return

	_dialogue_ui = DIALOGUE_UI_SCENE.instantiate() as DialogueUI

	if not is_instance_valid(_dialogue_ui):
		push_error("Não foi possível instanciar dialogue_ui.tscn.")
		set_process(false)
		return

	add_child(_dialogue_ui)

	_dialogue_ui.characters_per_second = characters_per_second
	_dialogue_ui.advance_requested.connect(_on_advance_requested)
	_dialogue_ui.close_dialogue()


func _process(_delta: float) -> void:
	if waiting_for_interaction_release:
		if not Input.is_action_pressed("primary"):
			waiting_for_interaction_release = false


func start_dialogue(data: DialogueData) -> bool:
	if is_dialogue_active or waiting_for_interaction_release:
		return false

	if data == null or data.lines.is_empty():
		push_warning("DialogueManager: DialogueData vazio ou não configurado.")
		return false

	if not is_instance_valid(_player) or not is_instance_valid(_dialogue_ui):
		return false

	if _player.player_input.in_inventory or _player.is_paused:
		return false

	_previous_can_move = _player.can_move
	_previous_can_pause = _player.can_pause
	_previous_mouse_mode = Input.get_mouse_mode()

	current_dialogue = data
	current_line_index = 0
	is_dialogue_active = true

	_player.can_move = false
	_player.can_pause = false
	_player.player_input.dialogue_locked = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_dialogue_ui.characters_per_second = characters_per_second
	_dialogue_ui.open_dialogue()

	_present_current_line()

	return true


func advance_dialogue() -> void:
	if not is_dialogue_active:
		return

	if _dialogue_ui.is_typing():
		_dialogue_ui.reveal_current_text()
		return

	current_line_index += 1

	if current_line_index >= current_dialogue.lines.size():
		end_dialogue()
		return

	_present_current_line()


func end_dialogue() -> void:
	if not is_dialogue_active:
		return

	is_dialogue_active = false
	waiting_for_interaction_release = true

	current_dialogue = null
	current_line_index = -1

	if is_instance_valid(_dialogue_ui):
		_dialogue_ui.close_dialogue()

	if is_instance_valid(_player):
		_player.player_input.dialogue_locked = false
		_player.can_move = _previous_can_move
		_player.can_pause = _previous_can_pause

	Input.set_mouse_mode(_previous_mouse_mode)


func _present_current_line() -> void:
	if current_dialogue == null:
		end_dialogue()
		return

	if current_line_index < 0 or current_line_index >= current_dialogue.lines.size():
		end_dialogue()
		return

	var line: DialogueLine = current_dialogue.lines[current_line_index]

	if line == null:
		push_warning("DialogueManager: existe uma fala nula no DialogueData.")
		advance_dialogue()
		return

	_dialogue_ui.present_line(line)


func _on_advance_requested() -> void:
	advance_dialogue()
