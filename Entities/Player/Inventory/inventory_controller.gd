
extends Control
class_name InventoryController

const DROP_HEIGHT := 1.0

@export var equipment_controller: EquipmentController

@onready var player = Global.player
@onready var inventory_canvas_layer: CanvasLayer = $".."
@onready var inventory_grid: GridContainer = %GridContainer
@onready var item_title: Label = %ItemTitle
@onready var item_description: RichTextLabel = %ItemDescription

var inventory_slot_prefab: PackedScene = load("res://Entities/Player/Inventory/slot.tscn")
var item_slots_count: int = 5
var inventory_slots: Array[InventorySlot] = []


func _ready() -> void:
	for i in item_slots_count:
		var slot := inventory_slot_prefab.instantiate() as InventorySlot
		inventory_grid.add_child(slot)
		slot.inventory_slot_id = i
		slot.num_slot.text = str(i + 1)
		inventory_slots.append(slot)


func _process(_delta: float) -> void:
	if not player:
		player = Global.player
		return

	handle_inventory_visibility()
	who_is_on_focus()

	if not get_viewport().gui_get_focus_owner():
		inventory_grid.get_child(0).grab_focus()


func _physics_process(_delta: float) -> void:
	if not player:
		return

	var equipment := player.get_node_or_null("EquipmentController") as EquipmentController

	if player.player_input.selected_slot_request >= 0:
		equip_slot(player.player_input.selected_slot_request)

	if player.player_input.in_inventory and player.player_input.equip_request:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is InventorySlot:
			equip_item_from_slot(focused)

	if player.player_input.drop_request:
		if player.player_input.in_inventory:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is InventorySlot:
				drop_item(focused)
		elif equipment != null and equipment.current_item != null:
			for slot in inventory_slots:
				if slot.slot_filled and slot.slot_data == equipment.current_item:
					drop_item(slot)
					break


func equip_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= inventory_slots.size():
		return

	var slot := inventory_slots[slot_index]
	var equipment := player.get_node_or_null("EquipmentController") as EquipmentController

	if equipment == null:
		push_warning("EquipmentController não encontrado no Player.")
		return

	if not slot.slot_filled or slot.slot_data == null:
		equipment.unequip_item()
		return

	if equipment.current_item == slot.slot_data:
		equipment.unequip_item()
		return

	equip_item_from_slot(slot)


func equip_item_from_slot(slot: InventorySlot) -> void:
	if slot == null or not slot.slot_filled or slot.slot_data == null:
		return

	var equipment := player.get_node_or_null("EquipmentController") as EquipmentController

	if equipment == null:
		push_warning("EquipmentController não encontrado no Player.")
		return

	equipment.equip_item(slot.slot_data)

	if equipment.current_item == slot.slot_data:
		player.player_input.in_inventory = false
		player.can_move = true


func handle_inventory_visibility() -> void:
	inventory_canvas_layer.visible = player.player_input.in_inventory


func who_is_on_focus() -> void:
	var on_focus_slot := get_viewport().gui_get_focus_owner()

	if on_focus_slot is InventorySlot:
		item_title.text = on_focus_slot.slot_title
		item_description.text = on_focus_slot.slot_description


func _is_inventory_full() -> bool:
	for slot in inventory_slots:
		if not slot.slot_filled:
			return false

	return true


func pickup_item(item_data: ItemData) -> bool:
	if item_data == null:
		return false

	for slot in inventory_slots:
		if not slot.slot_filled:
			slot.fill_slot(item_data)
			return true

	print("Inventário cheio! Não é possível coletar: ", item_data.display_name)
	return false


func drop_item(slot: InventorySlot) -> void:
	if slot == null or not slot.slot_filled:
		return

	var data: ItemData = slot.slot_data

	if data == null:
		return

	if data.world_scene_path.is_empty():
		push_warning("Item sem cena de mundo: " + data.display_name)
		return

	var world_scene := load(data.world_scene_path) as PackedScene

	if world_scene == null:
		push_warning("Não foi possível carregar: " + data.world_scene_path)
		return

	var world_item := world_scene.instantiate() as Node3D

	if world_item == null:
		push_warning("A raiz da cena de mundo precisa ser Node3D.")
		return

	var equipment := player.get_node_or_null("EquipmentController") as EquipmentController

	# Solta o item 1 metro acima da origem do personagem.
	var drop_position: Vector3 = player.global_position + Vector3.UP * DROP_HEIGHT

	get_tree().current_scene.add_child(world_item)
	world_item.global_position = drop_position

	# Desequipa o item caso esteja na mão.
	if equipment != null and equipment.current_item == data:
		equipment.unequip_item()

	# Remove o item do inventário.
	slot.clear_slot()
