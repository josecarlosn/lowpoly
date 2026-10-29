extends Control
class_name InventoryController

const DROP_HEIGHT := 1.0
const DROP_WALL_MARGIN := 0.15

@export var equipment_controller: EquipmentController

@export_group("Animação de Coleta")
@export var pickup_target: Node3D
@export var pickup_lift_height: float = 0.45
@export var pickup_lift_duration: float = 0.12
@export var pickup_fly_duration: float = 0.32
@export var pickup_arc_height: float = 0.15
@export var pickup_target_offset: Vector3 = Vector3(0, -0.15, 0)

@onready var player = Global.player
@onready var inventory_canvas_layer: CanvasLayer = $".."
@onready var inventory_grid: GridContainer = %GridContainer
@onready var item_title: Label = %ItemTitle
@onready var item_description: RichTextLabel = %ItemDescription

var inventory_slot_prefab: PackedScene = load(
	"res://Entities/Player/Inventory/slot.tscn"
)

var item_slots_count: int = 5
var inventory_slots: Array[InventorySlot] = []
var pickup_in_progress: bool = false


func _ready() -> void:
	for i in item_slots_count:
		var slot := inventory_slot_prefab.instantiate() as InventorySlot

		inventory_grid.add_child(slot)
		slot.inventory_slot_id = i
		slot.num_slot.text = str(i + 1)

		inventory_slots.append(slot)


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = Global.player
		return

	handle_inventory_visibility()
	who_is_on_focus()

	if not get_viewport().gui_get_focus_owner():
		if inventory_grid.get_child_count() > 0:
			inventory_grid.get_child(0).grab_focus()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return

	var input = player.player_input

	# Bloqueia equipar e dropar durante a coleta.
	if pickup_in_progress:
		input.drop_request = false
		input.equip_request = false
		input.selected_slot_request = -1
		return

	var equipment := _get_equipment_controller()

	# DROP TEM PRIORIDADE.
	if input.drop_request:
		input.drop_request = false
		input.equip_request = false
		input.selected_slot_request = -1

		if equipment != null and equipment.is_transitioning:
			return

		if input.in_inventory:
			var focused := get_viewport().gui_get_focus_owner()

			if focused is InventorySlot:
				drop_item(focused)

		elif equipment != null and equipment.current_item != null:
			for slot in inventory_slots:
				if (
					slot.slot_filled
					and slot.slot_data == equipment.current_item
				):
					drop_item(slot)
					break

		return

	# Seleção por atalho numérico.
	if input.selected_slot_request >= 0:
		var requested_slot: int = input.selected_slot_request

		input.selected_slot_request = -1
		input.equip_request = false

		if equipment == null or equipment.is_transitioning:
			return

		equip_slot(requested_slot)
		return

	# Equipar pela interface do inventário.
	if input.equip_request:
		input.equip_request = false

		if not input.in_inventory:
			return

		if equipment == null or equipment.is_transitioning:
			return

		var focused := get_viewport().gui_get_focus_owner()

		if focused is InventorySlot:
			equip_item_from_slot(focused)


func _get_equipment_controller() -> EquipmentController:
	if is_instance_valid(equipment_controller):
		return equipment_controller

	if not is_instance_valid(player):
		return null

	equipment_controller = player.get_node_or_null(
		"EquipmentController"
	) as EquipmentController

	return equipment_controller


func equip_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= inventory_slots.size():
		return

	var equipment := _get_equipment_controller()

	if equipment == null:
		push_warning("EquipmentController não encontrado no Player.")
		return

	if equipment.is_transitioning:
		return

	var slot := inventory_slots[slot_index]

	if not slot.slot_filled or slot.slot_data == null:
		await equipment.unequip_item()
		return

	if equipment.current_item == slot.slot_data:
		await equipment.unequip_item()
		return

	await equip_item_from_slot(slot)


func equip_item_from_slot(slot: InventorySlot) -> void:
	if slot == null or not slot.slot_filled or slot.slot_data == null:
		return

	var equipment := _get_equipment_controller()

	if equipment == null:
		push_warning("EquipmentController não encontrado no Player.")
		return

	if equipment.is_transitioning:
		return

	if equipment.current_item == slot.slot_data:
		await equipment.unequip_item()
		return

	await equipment.equip_item(slot.slot_data)

	# Fecha o inventário somente se o item foi equipado.
	if equipment.current_item == slot.slot_data:
		player.player_input.in_inventory = false
		player.can_move = true


func handle_inventory_visibility() -> void:
	inventory_canvas_layer.visible = player.player_input.in_inventory


func who_is_on_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()

	if focused is InventorySlot:
		item_title.text = focused.slot_title
		item_description.text = focused.slot_description


func _is_inventory_full() -> bool:
	for slot in inventory_slots:
		if not slot.slot_filled:
			return false

	return true


# =========================================================
# COLETA DE ITENS
# =========================================================

func pickup_item(
	item_data: ItemData,
	world_item: Node3D = null
) -> bool:
	if item_data == null or pickup_in_progress:
		return false

	# Procura um espaço livre antes de iniciar a coleta.
	var free_slot: InventorySlot = null

	for slot in inventory_slots:
		if not slot.slot_filled:
			free_slot = slot
			break

	if free_slot == null:
		print(
			"Inventário cheio! Não é possível coletar: ",
			item_data.display_name
		)
		return false

	# Sem instância do mundo, adiciona normalmente, sem animação.
	if not is_instance_valid(world_item):
		free_slot.fill_slot(item_data)
		return true

	if not is_instance_valid(pickup_target):
		push_warning(
			"Configure Pickup Target com o nó head do jogador."
		)
		return false

	# Adiciona ao inventário e inicia a animação.
	free_slot.fill_slot(item_data)
	pickup_in_progress = true

	_disable_pickup_collisions(world_item)
	_animate_pickup(world_item)

	return true


func _animate_pickup(world_item: Node3D) -> void:
	if not is_instance_valid(world_item):
		pickup_in_progress = false
		return

	var start_position: Vector3 = world_item.global_position

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_method(
		_update_pickup_flight.bind(world_item, start_position),
		0.0,
		1.0,
		pickup_fly_duration
	)

	await tween.finished

	if is_instance_valid(world_item):
		world_item.queue_free()

	pickup_in_progress = false


func _update_pickup_flight(
	progress: float,
	world_item: Node3D,
	start_position: Vector3
) -> void:
	if not is_instance_valid(world_item):
		return

	if not is_instance_valid(pickup_target):
		return

	var target_position: Vector3 = (
		pickup_target.global_position
		+ pickup_target_offset
	)

	world_item.global_position = start_position.lerp(
		target_position,
		progress
	)


func _disable_pickup_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0

	if node is Area3D:
		node.monitoring = false
		node.monitorable = false

	if node is RigidBody3D:
		node.freeze = true
		node.linear_velocity = Vector3.ZERO
		node.angular_velocity = Vector3.ZERO

	for child in node.get_children():
		_disable_pickup_collisions(child)


# =========================================================
# DROP DE ITENS
# =========================================================

# Traça um raio da cabeça do jogador até a posição desejada de drop.
# Se bater em algo (parede), devolve o ponto de impacto recuado.
func _get_safe_drop_position(desired: Vector3) -> Vector3:
	var origin: Vector3

	if is_instance_valid(pickup_target):
		origin = pickup_target.global_position
	else:
		origin = player.global_position + Vector3.UP * DROP_HEIGHT

	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, desired)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	# query.collision_mask = 1  # ajuste para a layer do mundo/paredes

	var hit := space.intersect_ray(query)

	if hit.is_empty():
		return desired

	return hit.position + hit.normal * DROP_WALL_MARGIN


func drop_item(slot: InventorySlot) -> void:
	if slot == null or not slot.slot_filled:
		return

	var data: ItemData = slot.slot_data

	if data == null:
		return

	var equipment := _get_equipment_controller()

	if equipment != null and equipment.is_transitioning:
		return

	if data.world_scene_path.is_empty():
		push_warning(
			"Item sem cena de mundo: " + data.display_name
		)
		return

	var world_scene := load(data.world_scene_path) as PackedScene

	if world_scene == null:
		push_warning(
			"Não foi possível carregar: " + data.world_scene_path
		)
		return

	var world_item := world_scene.instantiate() as Node3D

	if world_item == null:
		push_warning(
			"A raiz da cena de mundo precisa ser Node3D."
		)
		return

	var item_is_equipped := (
		equipment != null
		and equipment.current_item == data
	)

	var drop_position: Vector3
	var drop_rotation: Vector3

	# Captura a transformação antes de remover o item da mão.
	if item_is_equipped:
		if not is_instance_valid(equipment.equipped_instance):
			world_item.free()
			return

		drop_position = equipment.equipped_instance.global_position
		drop_rotation = equipment.equipped_instance.global_rotation

	elif (
		equipment != null
		and is_instance_valid(equipment.hand_anchor)
	):
		drop_position = equipment.hand_anchor.global_position
		drop_rotation = equipment.hand_anchor.global_rotation

	else:
		drop_position = (
			player.global_position + Vector3.UP * DROP_HEIGHT
		)
		drop_rotation = player.global_rotation

	var scene_root := get_tree().current_scene

	if scene_root == null:
		world_item.free()
		push_warning(
			"Não existe uma cena principal para receber o item."
		)
		return

	# Evita o item nascer dentro/atrás de paredes.
	drop_position = _get_safe_drop_position(drop_position)

	var collectable := world_item.find_child(
		"InteractionComponent",
		true,
		false
	) as CollectableInteraction

	if collectable != null:
		collectable.item_data = data

	scene_root.add_child(world_item)
	world_item.global_position = drop_position
	world_item.global_rotation = drop_rotation

	if item_is_equipped:
		if not equipment.remove_equipped_for_drop(data):
			world_item.queue_free()
			return

	slot.clear_slot()
