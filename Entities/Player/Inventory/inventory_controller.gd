
extends Control
class_name InventoryController

const DROP_HEIGHT := 0.0
const DROP_AIM_DISTANCE := 1.0
const DROP_WALL_MARGIN := 0.15
const DROP_QUERY_MARGIN := 0.03
const DROP_BLOCKED_HEIGHT_OFFSET := -0.45

@export_group("Drop Físico")
@export_range(0.1, 10.0, 0.1) var drop_throw_speed: float = 3.0
@export_range(0.0, 2.0, 0.05) var drop_player_collision_grace: float = 0.25
@export_range(0.0, 5.0, 0.1) var drop_downward_speed: float = 1.5

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
var drop_in_progress: bool = false


func _ready() -> void:
	InventoryManager.ensure_capacity(item_slots_count)

	for i in item_slots_count:
		var slot := inventory_slot_prefab.instantiate() as InventorySlot

		if slot == null:
			push_error("Não foi possível instanciar InventorySlot.")
			continue

		inventory_grid.add_child(slot)
		slot.inventory_slot_id = i
		slot.num_slot.text = str(i + 1)
		inventory_slots.append(slot)

		var saved_item: ItemData = InventoryManager.get_item(i)

		if saved_item != null:
			slot.fill_slot(saved_item)


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

	if pickup_in_progress or drop_in_progress:
		input.drop_request = false
		input.equip_request = false
		input.selected_slot_request = -1
		return

	var equipment := _get_equipment_controller()

	if input.drop_request:
		if equipment != null and (
			equipment.is_transitioning or equipment.action_locked
		):
			return

		input.drop_request = false
		input.equip_request = false
		input.selected_slot_request = -1

		var slot_to_drop: InventorySlot = null

		if input.in_inventory:
			var focused := get_viewport().gui_get_focus_owner()

			if focused is InventorySlot:
				slot_to_drop = focused

		elif equipment != null and equipment.current_item != null:
			for slot in inventory_slots:
				if slot.slot_filled and slot.slot_data == equipment.current_item:
					slot_to_drop = slot
					break

		if slot_to_drop != null:
			drop_item(slot_to_drop)

		return

	if equipment != null and equipment.action_locked:
		input.equip_request = false
		input.selected_slot_request = -1
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
	InventoryManager.set_item(free_slot.inventory_slot_id, runtime_item)

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
	InventoryManager.clear_slot(slot.inventory_slot_id)

	return true


func remove_item_reference(item_data: ItemData) -> bool:
	var slot := _find_slot_for_item(item_data)

	if slot == null:
		return false

	slot.clear_slot()
	InventoryManager.clear_slot(slot.inventory_slot_id)

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

func _get_player_camera() -> Camera3D:
	var equipment := _get_equipment_controller()

	if equipment != null and is_instance_valid(equipment.player_camera):
		return equipment.player_camera

	return player.get_node_or_null("head/Camera3D") as Camera3D


func _get_drop_reference_position() -> Vector3:
	var origin: Vector3 = player.global_position
	var camera := _get_player_camera()

	if camera != null:
		origin.y = camera.global_position.y
	else:
		origin.y += 1.0

	return origin


func _get_safe_hand_origin(
	hand_origin: Vector3,
	world_item: Node3D
) -> Vector3:
	var reference_position := _get_drop_reference_position()

	var safe_position := _sweep_item(
		reference_position,
		hand_origin,
		world_item
	)

	if safe_position == Vector3.INF:
		return Vector3.INF

	var hand_was_blocked := (
		safe_position.distance_to(hand_origin) > 0.05
	)

	if hand_was_blocked:
		safe_position.y += DROP_BLOCKED_HEIGHT_OFFSET

	if not _is_drop_position_clear(safe_position, world_item):
		return Vector3.INF

	return safe_position


func _get_aim_position(world_item: Node3D) -> Vector3:
	var camera := _get_player_camera()

	if camera == null:
		push_warning("Camera3D não encontrada. Usando a direção frontal do jogador.")

		return (
			player.global_position
			+ Vector3.UP * DROP_HEIGHT
			- player.global_transform.basis.z * DROP_AIM_DISTANCE
		)

	var ray_origin: Vector3 = camera.global_position

	var ray_end: Vector3 = (
		ray_origin
		- camera.global_transform.basis.z * DROP_AIM_DISTANCE
	)

	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end
	)

	query.exclude = _get_excluded_rids(world_item)
	query.collide_with_areas = false

	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return ray_end

	return hit.position


func _get_safe_drop_position(
	origin: Vector3,
	world_item: Node3D
) -> Vector3:
	var target := _get_aim_position(world_item)

	var candidate := _sweep_item(
		origin,
		target,
		world_item
	)

	if candidate == Vector3.INF:
		return Vector3.INF

	if _is_drop_position_clear(candidate, world_item):
		return candidate

	return Vector3.INF


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

		var shape_safe_fraction: float = result[0]

		if shape_safe_fraction < 1.0 and motion.length() > 0.001:
			shape_safe_fraction = maxf(
				0.0,
				shape_safe_fraction - DROP_WALL_MARGIN / motion.length()
			)

		safe_fraction = minf(
			safe_fraction,
			shape_safe_fraction
		)

		used_shapes += 1

	world_item.global_transform = original_transform

	if used_shapes == 0:
		return Vector3.INF

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
	if slot == null or not slot.slot_filled or drop_in_progress:
		return

	drop_in_progress = true
	_drop_item_sequence(slot)


func _drop_item_sequence(slot: InventorySlot) -> void:
	if not is_instance_valid(slot) or not slot.slot_filled:
		drop_in_progress = false
		return

	var data: ItemData = slot.slot_data

	if data == null:
		drop_in_progress = false
		return

	var equipment := _get_equipment_controller()

	var was_equipped := (
		equipment != null
		and equipment.current_item == data
	)

	var drop_origin: Vector3
	var drop_rotation: Vector3

	if was_equipped and is_instance_valid(equipment.equipped_instance):
		drop_origin = equipment.equipped_instance.global_position
		drop_rotation = equipment.equipped_instance.global_rotation

	elif equipment != null and is_instance_valid(equipment.hand_anchor):
		drop_origin = equipment.hand_anchor.global_position
		drop_rotation = equipment.hand_anchor.global_rotation

	else:
		drop_origin = player.global_position + Vector3.UP * DROP_HEIGHT
		drop_rotation = player.global_rotation

	await _spawn_and_launch_drop(
		slot,
		data,
		drop_origin,
		drop_rotation,
		equipment,
		was_equipped
	)

	drop_in_progress = false


func _spawn_and_launch_drop(
	slot: InventorySlot,
	data: ItemData,
	drop_origin: Vector3,
	drop_rotation: Vector3,
	equipment: EquipmentController,
	was_equipped: bool
) -> void:
	if data.world_scene_path.is_empty():
		push_warning("Item sem cena de mundo: " + data.name)
		return

	var world_scene := load(data.world_scene_path) as PackedScene

	if world_scene == null:
		push_warning("Não foi possível carregar: " + data.world_scene_path)
		return

	var world_item := world_scene.instantiate() as RigidBody3D

	if world_item == null:
		push_warning("A raiz da cena do item precisa ser RigidBody3D.")
		return

	var scene_root := get_tree().current_scene

	if scene_root == null:
		world_item.free()
		push_warning("Não existe uma cena principal para receber o item.")
		return

	var collectable := world_item.find_child(
		"InteractionComponent",
		true,
		false
	) as CollectableInteraction

	if collectable != null:
		collectable.item_data = data

	world_item.freeze = true
	world_item.linear_velocity = Vector3.ZERO
	world_item.angular_velocity = Vector3.ZERO

	scene_root.add_child(world_item)

	world_item.global_rotation = drop_rotation
	world_item.global_position = drop_origin

	# PRIMEIRA VERIFICAÇÃO:
	# Verifica se a mão está do lado seguro da parede.
	var safe_origin := _get_safe_hand_origin(
		drop_origin,
		world_item
	)

	if safe_origin == Vector3.INF:
		world_item.queue_free()
		return

	world_item.global_position = safe_origin

	# SEGUNDA VERIFICAÇÃO:
	# Verifica o trajeto até o destino.
	var safe_position := _get_safe_drop_position(
		safe_origin,
		world_item
	)

	if safe_position == Vector3.INF:
		world_item.queue_free()
		return

	if was_equipped:
		if equipment == null or not equipment.remove_equipped_for_drop(data):
			world_item.queue_free()
			push_warning("Não foi possível remover o item equipado.")
			return

	# =====================================================
	# NOVO CÁLCULO DA VELOCIDADE
	# =====================================================

	var displacement: Vector3 = safe_position - safe_origin

	# Usa somente a direção horizontal do destino seguro.
	var horizontal_direction := Vector3(
		displacement.x,
		0.0,
		displacement.z
	)

	if horizontal_direction.length_squared() > 0.0001:
		horizontal_direction = horizontal_direction.normalized()
	else:
		var camera := _get_player_camera()

		if camera != null:
			horizontal_direction = -camera.global_transform.basis.z
		else:
			horizontal_direction = -player.global_transform.basis.z

		horizontal_direction.y = 0.0
		horizontal_direction = horizontal_direction.normalized()

	# Lança para frente e para baixo.
	var initial_velocity := (
		horizontal_direction * drop_throw_speed
		+ Vector3.DOWN * drop_downward_speed
	)

	# =====================================================

	var player_collision_exception := player is PhysicsBody3D

	if player_collision_exception:
		world_item.add_collision_exception_with(player)

	world_item.freeze = false
	world_item.sleeping = false
	world_item.linear_velocity = initial_velocity
	world_item.angular_velocity = Vector3.ZERO

	slot.clear_slot()
	InventoryManager.clear_slot(slot.inventory_slot_id)

	if player_collision_exception:
		_remove_temporary_player_collision_exception(world_item)


func _remove_temporary_player_collision_exception(
	rigid: RigidBody3D
) -> void:
	if drop_player_collision_grace > 0.0:
		await get_tree().create_timer(
			drop_player_collision_grace
		).timeout

	if is_instance_valid(rigid) and is_instance_valid(player):
		rigid.remove_collision_exception_with(player)
