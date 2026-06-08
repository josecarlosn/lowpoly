extends Control
class_name InventorySlot

@onready var icon: TextureRect = %TextureRect
var empty_icon: Texture = preload("uid://ckirht210g37o")
var slot_filled: bool = false
var slot_data: ItemData
func _ready() -> void:
	icon.texture = empty_icon
	pass
	
func fill_slot(item_data: ItemData) -> void:
	slot_data = item_data
	if slot_data != null:
		slot_filled = true
		icon.texture = item_data.item_icon
	else:
		print("nulo")
		slot_filled = false
		icon.texture = empty_icon
