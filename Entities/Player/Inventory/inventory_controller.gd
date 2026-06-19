extends Control
class_name InventoryController

@onready var player = Global.player
@onready var inventory_canvas_layer: CanvasLayer = $".."
@onready var inventory_grid: GridContainer = %GridContainer

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
	
func _process(delta: float) -> void:
	if not player:
		player = Global.player
		return
	handle_inventory_visibility()
		
func handle_inventory_visibility():
	inventory_canvas_layer.visible = player.player_input.in_inventory
	if inventory_canvas_layer.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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
			inventory_full = _is_inventory_full()
			print("Item adicionado ao slot: ", item_data.name)
			return # CORREÇÃO 2: Interrompe a função aqui para colocar em apenas UM slot!
			
	# Se saiu do loop e não achou slot livre (segurança extra)
	inventory_full = true
