
extends Area3D

@export var dialogue_data: DialogueData
@export var trigger_once: bool = true

var already_triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if already_triggered:
		return

	# Verifica se quem entrou na área é o jogador.
	if not body is Player:
		return

	# Encontra o DialogueManager dentro do Player.
	var manager := body.get_node_or_null(
		"DialogueManager"
	) as DialogueManager

	if not is_instance_valid(manager):
		push_warning("DialogueManager não encontrado no Player.")
		return

	# Inicia o diálogo.
	var started := manager.start_dialogue(dialogue_data)

	if started and trigger_once:
		already_triggered = true
