class_name EquipmentController
extends Node

@export var hand_anchor: Node3D
var current_item: ItemData
var equipped_instance: Node3D

func equip_item(item_data: ItemData) -> void:
	if item_data == null:
		return
	if item_data.hand_scene_path.is_empty():
		push_warning("Este item não possui cena para a mão.")
		return
	var packed_scene := load(item_data.hand_scene_path) as PackedScene
	if packed_scene == null:
		push_warning("Não foi possível carregar a cena da mão.")
		return
	unequip_item()

	equipped_instance = packed_scene.instantiate() as Node3D

	if equipped_instance == null:
		push_warning("A cena equipada precisa ter um Node3D como raiz.")
		return

	hand_anchor.add_child(equipped_instance)
	current_item = item_data


func unequip_item() -> void:
	if is_instance_valid(equipped_instance):
		equipped_instance.queue_free()

	equipped_instance = null
	current_item = null
