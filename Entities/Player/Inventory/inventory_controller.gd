extends Control
class_name InventoryController

@onready var player = Global.player
@onready var inventory_canvas_layer: CanvasLayer = $".."
@onready var inventory_grid: GridContainer = %GridContainer
@onready var item_title: Label = %ItemTitle
@onready var item_description: RichTextLabel = %ItemDescription

var inventory_slot_prefab: PackedScene = load("res://Entities/Player/Inventory/slot.tscn")
var item_slots_count: int = 5

# Aqui vão ficar guardadas as referências dos slots na memória
var inventory_slots: Array[InventorySlot] = []
var inventory_full: bool = false
 

func _ready() -> void:
	for item in item_slots_count:
		var slot = inventory_slot_prefab.instantiate() as InventorySlot
		inventory_grid.add_child(slot)
		# CORREÇÃO 1: Adiciona o slot instanciado na Array para podermos acessá-lo depois
		inventory_slots.append(slot)
	# Enumera os slotsdd
	for i in inventory_slots.size():
		inventory_slots[i].num_slot.text = str(i + 1)
func _process(delta: float) -> void:
	who_is_on_focus()
	if not player:
		player = Global.player
		return
	handle_inventory_visibility()
	
	if not inventory_grid.get_viewport().gui_get_focus_owner():
		inventory_grid.get_child(0).grab_focus()

func who_is_on_focus() -> void:
	var on_focus_slot = inventory_grid.get_viewport().gui_get_focus_owner()
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

func pickup_item(item_data: ItemData) -> void:
	# Se o inventário já estiver cheio, nem tenta adicionar
	if inventory_full:
		print("Inventário cheio! Não é possível coletar: ", item_data)
		return
	for slot in inventory_slots:
		if not slot.slot_filled:
			slot.fill_slot(item_data)
			slot.slot_title = item_data.name
			slot.slot_description = item_data.description
			inventory_full = _is_inventory_full()
			print("Item adicionado ao slot: ", item_data.name)
			return # CORREÇÃO 2: Interrompe a função aqui para colocar em apenas UM slot!
			
	# Se saiu do loop e não achou slot livre (segurança extra)
	inventory_full = true
