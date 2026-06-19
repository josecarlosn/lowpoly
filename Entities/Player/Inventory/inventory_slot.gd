extends Control
class_name InventorySlot

@onready var player = Global.player
@onready var icon: TextureRect = %InventoryTextureRect

var inventory_slot_id: int = -1
var empty_icon: Texture = preload("uid://ckirht210g37o")
var slot_filled: bool = false
var slot_data: ItemData

signal ont_item_swapped(from_slot_id: int, to_slot_id: int)
signal on_double_clicked(slot_id: int)
signal on_item_right_clicked(slot_id: int)

func _ready() -> void:
	icon.texture = empty_icon
	pass
# fill_slot é chamado na função pickup_item no inventory_controller.gd
func fill_slot(item_data: ItemData) -> void: # Eu diria que é nessa fuinção que futuramente salvaremos persistentemente os dados do inventário
	slot_data = item_data
	if slot_data != null:
		slot_filled = true
		icon.texture = item_data.item_icon
	else:
		print("_____________slot nulo!_____________")
		slot_filled = false
		icon.texture = empty_icon

func _get_drag_data(at_position: Vector2) -> Variant:
	if slot_filled:
		var preview: TextureRect = TextureRect.new()
		preview.texture = icon.texture
		set_drag_preview(preview)
		
	return null

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return false
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	return
