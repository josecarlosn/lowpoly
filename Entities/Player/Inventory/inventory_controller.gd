extends Control
class_name InventoryController

const DROP_DISTANCE := 0.4
const DROP_MARGIN := 0.2        # folga entre o item e a parede
const DROP_COLLISION_MASK := 1 | 16   # camada 1 (paredes/chão) + camada 5 (porta)

@onready var player = Global.player
@onready var inventory_canvas_layer: CanvasLayer = $".."
@onready var inventory_grid: GridContainer = %GridContainer
@onready var item_title: Label = %ItemTitle
@onready var item_description: RichTextLabel = %ItemDescription

var inventory_slot_prefab: PackedScene = load("res://Entities/Player/Inventory/slot.tscn")
var item_slots_count: int = 5
var inventory_slots: Array[InventorySlot] = []

func _ready() -> void:
	# CRIAÇÃO DOS SLOTS NO INVENTÁRIO
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

	# Garante que sempre exista um slot com foco (navegação por teclado)
	if not get_viewport().gui_get_focus_owner():
		inventory_grid.get_child(0).grab_focus()

# O drop lê o player_input no MESMO ciclo em que o poll() escreve (física),
# senão o aperto da tecla pode se perder quando o FPS oscila.
func _physics_process(_delta: float) -> void:
	if not player:
		return
	if player.player_input.in_inventory and player.player_input.drop_request:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is InventorySlot:
			drop_item(focused)

# --- INTERFACE ---------------------------------------------------------------

func handle_inventory_visibility() -> void:
	inventory_canvas_layer.visible = player.player_input.in_inventory

func who_is_on_focus() -> void:
	# Mostra título e descrição do slot em foco
	var on_focus_slot := get_viewport().gui_get_focus_owner()
	if on_focus_slot is InventorySlot:
		item_title.text = on_focus_slot.slot_title
		item_description.text = on_focus_slot.slot_description

# --- COLETAR -----------------------------------------------------------------

func _is_inventory_full() -> bool:
	for slot in inventory_slots:
		if not slot.slot_filled:
			return false
	return true

## Guarda o item no primeiro slot livre. Retorna false se estiver cheio.
func pickup_item(item_data: ItemData) -> bool:
	for slot in inventory_slots:
		if not slot.slot_filled:
			slot.fill_slot(item_data)   # o slot já define título, descrição e modelo 3D
			return true
	print("Inventário cheio! Não é possível coletar: ", item_data.name)
	return false

# --- DROPAR ------------------------------------------------------------------

## Tira o item do slot e cria ele no mundo, na frente da câmera.
func drop_item(slot: InventorySlot) -> void:
	if slot == null or not slot.slot_filled:
		return

	var data: ItemData = slot.slot_data
	if data.world_scene_path.is_empty():
		push_warning("Item sem cena de mundo: " + data.name)
		return

	# 1. cria o item no mundo
	var scene := load(data.world_scene_path) as PackedScene
	var item := scene.instantiate() as Node3D
	get_tree().current_scene.add_child(item)

	# 2. posiciona na frente da câmera (sem atravessar parede)
	var cam := get_viewport().get_camera_3d()
	item.global_position = _get_drop_position(cam)

	# 3. tira do inventário
	slot.clear_slot()

## Ponto de drop: 0,8 m à frente, ou logo antes de uma parede se houver uma no caminho.
func _get_drop_position(cam: Camera3D) -> Vector3:
	var from := cam.global_position
	var forward := -cam.global_basis.z
	var to := from + forward * DROP_DISTANCE

	var query := PhysicsRayQueryParameters3D.create(from, to, DROP_COLLISION_MASK)
	query.exclude = [player.get_rid()]

	var hit := cam.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to

	var distance := maxf(from.distance_to(hit.position) - DROP_MARGIN, 0.0)
	return from + forward * distance
