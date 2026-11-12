extends Node
class_name DialogueInteraction

@export_category("Dialogue")
@export var dialogue_data: DialogueData

@export_category("Interaction Labels")
@export var hover_label: String = "Conversar"
@export var interact_label: String = ""

var can_interact: bool = true


func pre_interact() -> void:
	pass


func interact() -> void:
	if not can_interact:
		return

	var player: Player = Global.player as Player
	if not is_instance_valid(player):
		push_warning("DialogueInteraction: Player global não encontrado.")
		return

	print("Global.player: ", player)
	print("Caminho do Player: ", player.get_path())
	print("Filhos do Player: ", player.get_children())

	var manager := player.get_node_or_null("DialogueManager") as DialogueManager

	print("DialogueManager encontrado: ", manager)
	if not is_instance_valid(manager):
		push_warning("DialogueInteraction: DialogueManager não encontrado no Player.")
		return

	manager.start_dialogue(dialogue_data)


func post_interact() -> void:
	pass
