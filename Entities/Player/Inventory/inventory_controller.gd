extends Control
class_name InventoryController

@onready var player = Global.player
@onready var inventory_canvas_layer: CanvasLayer = $".."
@onready var inventory_grid: GridContainer = %GridContainer
@onready var item_title: Label = %ItemTitle
@onready var item_description: RichTextLabel = %ItemDescription

var inventory_slot_prefab: PackedScene = load("res://Entities/Player/Inventory/slot.tscn")
var item_slots_count: int = 5
var inventory_slots: Array[InventorySlot] = []
var inventory_full: bool = false
var selected_slot: InventorySlot
func _ready() -> void:
	# CRIAÇÃO DOS SLOTS NO INVENTÁRIO
	for item in item_slots_count:
		var slot = inventory_slot_prefab.instantiate() as InventorySlot
		inventory_grid.add_child(slot)
		inventory_slots.append(slot)
	# ENUMERAÇÃO DOS SLOTS DO INVENTÁRIO	
	for i in inventory_slots.size():
		inventory_slots[i].num_slot.text = str(i + 1)
	for slot in inventory_slots:
		slot.focus_entered.connect(_select_slot.bind(slot))
		slot.mouse_entered.connect(_select_slot.bind(slot))
	selected_slot = inventory_slots[0]

func _select_slot(slot: InventorySlot) -> void:
	selected_slot = slot	
func _process(delta: float) -> void:

	who_is_on_focus() 
	if not player:
		player = Global.player
		return
	handle_inventory_visibility()
	
	if not inventory_grid.get_viewport().gui_get_focus_owner():
		inventory_grid.get_child(0).grab_focus()
		
	if player.player_input.drop_request:
		player.player_input.drop_request = false    # consumiu
		if player.player_input.in_inventory:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is InventorySlot:
				drop_item(focused)
		
func who_is_on_focus() -> void:
	#RECEBE QUAL SLOT ESTÁ SELECIONADO (EM FOCO)
	var on_focus_slot = inventory_grid.get_viewport().gui_get_focus_owner()
	
	#SE EXISTIR SLOT SELECIONADO APLICA TÍTULO E DESCRIÇÃO
	if on_focus_slot:
		item_title.text = on_focus_slot.slot_title
		item_description.text = on_focus_slot.slot_description
		
func handle_inventory_visibility():
	inventory_canvas_layer.visible = player.player_input.in_inventory


func _is_inventory_full() -> bool:
	for slot in inventory_slots:
		# Verifica se o slot está marcado como não preenchido
		if not slot.slot_filled:
			return false
	return true
	
func pickup_item(item_data: ItemData) -> bool:
	if inventory_full:
		print("Inventário cheio! Não é possível coletar: ", item_data.name)
		return false

	for slot in inventory_slots:
		if not slot.slot_filled:
			slot.fill_slot(item_data)
			slot.slot_title = item_data.name
			slot.slot_description = item_data.description
			inventory_full = _is_inventory_full()
			return true          # <- é isso que faltava

	inventory_full = true
	return false
func drop_item(slot: InventorySlot) -> void:
	if slot == null or not slot.slot_filled:
		return
	var data: ItemData = slot.slot_data
	if data.world_scene_path.is_empty():
		push_warning("Item sem cena de mundo: " + data.name)
		return

	# 1. cria o item no mundo
	var scene: PackedScene = load(data.world_scene_path)
	var item := scene.instantiate() as Node3D
	get_tree().current_scene.add_child(item)

	# 2. coloca na frente da câmera
	var cam := get_viewport().get_camera_3d()
	item.global_position = cam.global_position + (-cam.global_basis.z * 0.8)

	# 3. tira do inventário
	slot.clear_slot()
	inventory_full = false   # senão você nunca mais consegue coletar
