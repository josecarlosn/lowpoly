
extends Node

const LABEL_MESSAGE_DURATION: float = 3.0
const MAX_INTERACTION_DISTANCE: float = 3.0

@onready var interact_ray: ShapeCast3D = %interactRay
@onready var player: Player = get_parent() as Player
@onready var label: Label = %Label
@onready var inventory_controller: InventoryController = get_node(
	"../InventoryController/InventoryCanvasLayer/PlayerInventoryUI"
) as InventoryController

var current_object: Object
var interact_component

var current_hit_position: Vector3 = Vector3.ZERO

var label_timer: Timer
var temporary_message_active: bool = false
var temporary_message_text: String = ""

var press_interaction_active: bool = false
var hold_interaction_active: bool = false
var interaction_prepared: bool = false

signal invent_on_item_collected(
	item_data: ItemData,
	world_item: Node3D
)


func _ready() -> void:
	invent_on_item_collected.connect(inventory_controller.pickup_item)

	label_timer = Timer.new()
	label_timer.one_shot = true
	label_timer.wait_time = LABEL_MESSAGE_DURATION
	add_child(label_timer)
	label_timer.timeout.connect(_on_label_timer_timeout)

	if is_instance_valid(player) and player is CollisionObject3D:
		interact_ray.add_exception(player)

	_unfocus()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = Global.player

		if is_instance_valid(player) and player is CollisionObject3D:
			interact_ray.add_exception(player)

		_clear_interaction()
		return

	# Durante o arrasto, mantém o objeto original,
	# mas continua verificando a distância.
	if press_interaction_active:
		if (
			not Input.is_action_pressed("primary")
			or player.player_input.in_inventory
		):
			_end_press_interaction()
			return

		if not _is_current_object_in_range():
			_clear_interaction()
			return

		_update_active_interaction(delta)
		return

	var action_controller := _get_item_action_controller()
	var potential_object: Object = _get_closest_collider()

	# Sem um objeto interativo válido.
	if not potential_object is Node:
		_clear_interaction()
		return

	var candidate := (potential_object as Node).get_node_or_null(
		"InteractionComponent"
	)

	if not is_instance_valid(candidate) or not candidate.can_interact:
		_clear_interaction()
		return

	# Verifica se o alvo mudou.
	if current_object != null and current_object != potential_object:
		_clear_interaction()

	interact_component = candidate

	# Mantém a conexão dos objetos coletáveis.
	if (
		interact_component is CollectableInteraction
		and not interact_component.is_connected(
			"item_collected",
			Callable(self, "_on_item_collected")
		)
	):
		interact_component.connect(
			"item_collected",
			Callable(self, "_on_item_collected")
		)

	# Não interfere enquanto uma ação de item estiver em andamento.
	if action_controller != null and action_controller.action_in_progress:
		return

	# Mensagens temporárias têm prioridade.
	if temporary_message_active:
		return

	_focus()

	# Inicia a interação apenas no instante do clique.
	if (
		Input.is_action_just_pressed("primary")
		and not player.player_input.in_inventory
	):
		current_object = potential_object

		interact_component.pre_interact()
		interaction_prepared = true

		if action_controller != null and action_controller_has_equipped_item():
			var result: ItemUseResult = await action_controller.try_use_on_target(
				interact_component
			)

			if result.status != ItemUseResult.Status.NOT_HANDLED:
				if not result.message.is_empty():
					_show_temporary_message(result.message)

				_end_press_interaction()
				return

		if (
			is_instance_valid(interact_component)
			and interact_component.can_interact
		):
			# Executa a interação inicial uma única vez.
			interact_component.interact()

			if not interact_component.interact_label.is_empty():
				_show_temporary_message(interact_component.interact_label)

			# Inicia o arrasto somente em objetos compatíveis.
			if interact_component.has_method("hold_interact"):
				var hold_started: bool = true

				# Entrega o ponto exato atingido pelo ShapeCast
				# e o Marker3D da mão do jogador.
				if interact_component.has_method("begin_hold_interact"):
					var player_hand := player.hand as Marker3D

					hold_started = interact_component.begin_hold_interact(
						current_hit_position,
						player_hand
					)

				if hold_started:
					press_interaction_active = true
					hold_interaction_active = true
				else:
					_end_press_interaction()


func _is_current_object_in_range() -> bool:
	if not is_instance_valid(current_object):
		return false

	if not current_object is Node3D:
		return false

	var target := current_object as Node3D

	var distance := interact_ray.global_position.distance_to(
		target.global_position
	)

	return distance <= MAX_INTERACTION_DISTANCE


func _update_active_interaction(delta: float) -> void:
	if not press_interaction_active or not hold_interaction_active:
		return

	if not is_instance_valid(interact_component):
		_clear_interaction()
		return

	if not interact_component.can_interact:
		_clear_interaction()
		return

	if interact_component.has_method("hold_interact"):
		interact_component.hold_interact(delta)


func _end_press_interaction() -> void:
	if interaction_prepared and is_instance_valid(interact_component):
		interact_component.post_interact()

	interaction_prepared = false
	press_interaction_active = false
	hold_interaction_active = false


func _interact_without_target(
	action_controller: ItemActionController
) -> void:
	if action_controller == null:
		return

	await action_controller.use_primary()


func action_controller_has_equipped_item() -> bool:
	if not is_instance_valid(player):
		return false

	var equipment := player.get_node_or_null(
		"EquipmentController"
	) as EquipmentController

	return equipment != null and equipment.current_item != null


func _get_item_action_controller() -> ItemActionController:
	if not is_instance_valid(player):
		return null

	return player.get_node_or_null(
		"ItemActionController"
	) as ItemActionController


func _get_closest_collider() -> Object:
	current_hit_position = Vector3.ZERO

	if not interact_ray.is_colliding():
		return null

	var origin: Vector3 = interact_ray.global_position
	var closest: Object = null
	var closest_dist: float = INF

	for i in range(interact_ray.get_collision_count()):
		var point: Vector3 = interact_ray.get_collision_point(i)
		var distance: float = origin.distance_squared_to(point)

		if distance < closest_dist:
			closest_dist = distance
			closest = interact_ray.get_collider(i)
			current_hit_position = point

	return closest


func _show_temporary_message(message: String) -> void:
	if message.is_empty():
		return

	temporary_message_text = message
	temporary_message_active = true

	label.text = temporary_message_text
	label.visible = true

	label_timer.start(LABEL_MESSAGE_DURATION)


func _on_label_timer_timeout() -> void:
	temporary_message_active = false


func _clear_interaction() -> void:
	_end_press_interaction()

	current_object = null
	interact_component = null
	current_hit_position = Vector3.ZERO

	temporary_message_active = false
	temporary_message_text = ""

	if is_instance_valid(label_timer):
		label_timer.stop()

	_unfocus()


func _focus() -> void:
	if temporary_message_active:
		return

	if (
		is_instance_valid(label)
		and is_instance_valid(interact_component)
		and interact_component.can_interact
	):
		label.text = interact_component.hover_label
		label.visible = true
	else:
		_unfocus()


func _unfocus() -> void:
	if temporary_message_active:
		return

	if is_instance_valid(label):
		label.text = ""
		label.visible = false


func _on_item_collected(item: Node) -> void:
	if not is_instance_valid(item):
		return

	var ic := item.get_node_or_null(
		"InteractionComponent"
	) as CollectableInteraction

	if ic == null or ic.item_data == null:
		return

	var item_data: ItemData = ic.item_data
	var world_item := _get_world_item_node(item)

	if world_item == null:
		push_warning(
			"Não foi possível encontrar o objeto Node3D para animar a coleta."
		)
		ic.can_interact = true
		ic.is_collecting = false
		return

	if not inventory_controller.pickup_item(item_data, world_item):
		ic.can_interact = true
		ic.is_collecting = false
		return


func _get_world_item_node(item: Node) -> Node3D:
	var root := item.get_parent()

	if (
		root is Node3D
		and root.scene_file_path != ""
		and root.get_child_count() == 1
	):
		return root as Node3D

	return item as Node3D


func _add_item_to_inventory(
	item_data: ItemData,
	world_item: Node3D = null
) -> void:
	if item_data == null:
		print("ItemData não encontrado.")
		return

	invent_on_item_collected.emit(item_data, world_item)
