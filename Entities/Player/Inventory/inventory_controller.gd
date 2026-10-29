extends Control
class_name InventoryController

const DROP_HEIGHT := 1.0
const DROP_WALL_MARGIN := 0.15
const DROP_QUERY_MARGIN := 0.03
const DROP_FALLBACK_HEIGHT := 0.5
const DROP_FRONT_DISTANCE := 0.5

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

	if pickup_in_progress:
		input.drop_request = false
		input.equip_request = false
		input.selected_slot_request = -1
		return

	var equipment := _get_equipment_controller()

	if equipment != null and equipment.action_locked:
		input.drop_request = false
		input.equip_request = false
		input.selected_slot_request = -1
		return

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

	if input.selected_slot_request >= 0:
		var requested_slot: int = input.selected_slot_request

		input.selected_slot_request = -1
		input.equip_request = false

		if equipment == null or equipment.is_transitioning:
			return

		equip_slot(requested_slot)
		return

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

	if equipment.is_transitioning or equipment.action_locked:
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

	if equipment.is_transitioning or equipment.action_locked:
		return

	if equipment.current_item == slot.slot_data:
		await equipment.unequip_item()
		return

	await equipment.equip_item(slot.slot_data)

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

	var free_slot: InventorySlot = null

	for slot in inventory_slots:
		if not slot.slot_filled:
			free_slot = slot
			break

	if free_slot == null:
		print("Inventário cheio! Não é possível coletar: ", item_data.name)
		return false

	if is_instance_valid(world_item) and not is_instance_valid(pickup_target):
		push_warning("Configure Pickup Target com o nó head do jogador.")
		return false

	var runtime_item := item_data.create_runtime_copy()
	free_slot.fill_slot(runtime_item)

	# Se o item veio do chão, inicia a animação e o autoequipamento.
	if is_instance_valid(world_item):
		pickup_in_progress = true
		_disable_pickup_collisions(world_item)
		_animate_pickup_and_equip(world_item, runtime_item)

	return true


func _animate_pickup_and_equip(
	world_item: Node3D,
	item_data: ItemData
) -> void:
	await _animate_pickup(world_item)

	# A animação terminou; tenta equipar o item coletado.
	await _auto_equip_item(item_data)


func _auto_equip_item(item_data: ItemData) -> void:
	var equipment := _get_equipment_controller()

	if equipment == null:
		push_warning("EquipmentController não encontrado no Player.")
		return

	if equipment.action_locked or equipment.is_transitioning:
		return

	await equipment.equip_item(item_data)

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
# CONSUMO / TRANSFERÊNCIA DE ITENS
# =========================================================

func consume_item(item_data: ItemData) -> bool:
	var slot := _find_slot_for_item(item_data)

	if slot == null:
		return false

	var equipment := _get_equipment_controller()

	if equipment != null and equipment.current_item == item_data:
		await equipment.unequip_item(true)

	slot.clear_slot()
	return true


func remove_item_reference(item_data: ItemData) -> bool:
	var slot := _find_slot_for_item(item_data)

	if slot == null:
		return false

	slot.clear_slot()
	return true


func _find_slot_for_item(item_data: ItemData) -> InventorySlot:
	if item_data == null:
		return null

	for slot in inventory_slots:
		if slot.slot_filled and slot.slot_data == item_data:
			return slot

	return null


# =========================================================
# POSIÇÃO SEGURA PARA DROP
# =========================================================
# IMPORTANTE: world_item precisa já estar dentro da árvore de cena
# (add_child) para que global_transform e as consultas de física
# funcionem corretamente.

func _get_safe_drop_position(
	desired: Vector3,
	world_item: Node3D
) -> Vector3:
	var head: Vector3

	if is_instance_valid(pickup_target):
		head = pickup_target.global_position
	else:
		head = player.global_position + Vector3.UP * DROP_HEIGHT

	var feet: Vector3 = (
		player.global_position + Vector3.UP * DROP_FALLBACK_HEIGHT
	)

	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var in_front: Vector3 = head + forward * DROP_FRONT_DISTANCE

	# Cada tentativa: [origem do sweep, destino do sweep]
	var attempts: Array = [
		[head, desired],
		[head, in_front],
		[head, feet],
		[feet, feet],
	]

	for attempt in attempts:
		var origin: Vector3 = attempt[0]
		var target: Vector3 = attempt[1]
		var candidate := _sweep_item(origin, target, world_item)

		if candidate == Vector3.INF:
			continue

		if _is_drop_position_clear(candidate, world_item):
			return candidate

	return Vector3.INF


# Arrasta o formato de colisão do item de origin até target e devolve
# a última posição sem colisão. Como o sweep usa o volume do item,
# ele não atravessa frestas entre paredes (ao contrário de um raycast).
func _sweep_item(
	origin: Vector3,
	target: Vector3,
	world_item: Node3D
) -> Vector3:
	if not world_item.is_inside_tree():
		return Vector3.INF

	var space := player.get_world_3d().direct_space_state
	var original_transform := world_item.global_transform

	world_item.global_position = origin

	var shapes: Array[CollisionShape3D] = []
	_collect_collision_shapes(world_item, shapes)

	var excluded := _get_excluded_rids(world_item)
	var motion: Vector3 = target - origin
	var safe_fraction: float = 1.0
	var used_shapes: int = 0

	for collision_shape in shapes:
		if (
			not is_instance_valid(collision_shape)
			or collision_shape.disabled
			or collision_shape.shape == null
		):
			continue

		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision_shape.shape
		query.transform = collision_shape.global_transform
		query.motion = motion
		query.exclude = excluded
		query.collide_with_areas = false
		query.margin = DROP_QUERY_MARGIN

		var result: PackedFloat32Array = space.cast_motion(query)

		if result.size() < 2:
			continue

		safe_fraction = minf(safe_fraction, result[0])
		used_shapes += 1

	world_item.global_transform = original_transform

	if used_shapes == 0:
		return Vector3.INF

	# Começou dentro de algo e não conseguiu se mover.
	if safe_fraction <= 0.0 and motion.length() > 0.001:
		return Vector3.INF

	return origin + motion * safe_fraction


func _get_excluded_rids(world_item: Node3D) -> Array[RID]:
	var excluded: Array[RID] = []

	if is_instance_valid(player):
		excluded.append(player.get_rid())

	_collect_collision_rids(world_item, excluded)

	return excluded


func _collect_collision_rids(
	node: Node,
	excluded: Array[RID]
) -> void:
	if node is CollisionObject3D:
		excluded.append(node.get_rid())

	for child in node.get_children():
		_collect_collision_rids(child, excluded)


func _is_drop_position_clear(
	candidate: Vector3,
	world_item: Node3D
) -> bool:
	if not world_item.is_inside_tree():
		push_warning(
			"world_item precisa estar na árvore para validar o drop."
		)
		return false

	var space := player.get_world_3d().direct_space_state
	var original_transform := world_item.global_transform

	world_item.global_position = candidate

	var shapes: Array[CollisionShape3D] = []
	_collect_collision_shapes(world_item, shapes)

	var excluded := _get_excluded_rids(world_item)
	var clear := not shapes.is_empty()

	for collision_shape in shapes:
		if (
			not is_instance_valid(collision_shape)
			or collision_shape.disabled
			or collision_shape.shape == null
		):
			continue

		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision_shape.shape
		query.transform = collision_shape.global_transform
		query.exclude = excluded
		query.collide_with_areas = false
		query.margin = DROP_QUERY_MARGIN

		if not space.intersect_shape(query, 1).is_empty():
			clear = false
			break

	world_item.global_transform = original_transform

	return clear


func _collect_collision_shapes(
	node: Node,
	shapes: Array[CollisionShape3D]
) -> void:
	if node is CollisionShape3D:
		shapes.append(node)

	for child in node.get_children():
		_collect_collision_shapes(child, shapes)


# =========================================================
# DROP DE ITENS
# =========================================================

func drop_item(slot: InventorySlot) -> void:
	if slot == null or not slot.slot_filled:
		return

	var data: ItemData = slot.slot_data

	if data == null:
		return

	var equipment := _get_equipment_controller()

	if equipment != null and (
		equipment.is_transitioning
		or equipment.action_locked
	):
		return

	if data.world_scene_path.is_empty():
		push_warning(
			"Item sem cena de mundo: " + data.name
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

	var collectable := world_item.find_child(
		"InteractionComponent",
		true,
		false
	) as CollectableInteraction

	if collectable != null:
		collectable.item_data = data

	# Entra na árvore congelado, para a validação de física funcionar
	# sem o item cair/ser empurrado antes da hora.
	var rigid := world_item as RigidBody3D

	if rigid != null:
		rigid.freeze = true

	scene_root.add_child(world_item)
	world_item.global_rotation = drop_rotation

	var safe_position := _get_safe_drop_position(
		drop_position,
		world_item
	)

	if safe_position == Vector3.INF:
		world_item.queue_free()
		push_warning(
			"Não foi encontrada uma posição segura para dropar o item."
		)
		return

	world_item.global_position = safe_position

	if item_is_equipped:
		if not equipment.remove_equipped_for_drop(data):
			world_item.queue_free()
			return

	if rigid != null:
		rigid.linear_velocity = Vector3.ZERO
		rigid.angular_velocity = Vector3.ZERO
		rigid.freeze = false

	slot.clear_slot()
