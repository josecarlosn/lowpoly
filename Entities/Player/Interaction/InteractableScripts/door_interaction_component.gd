
extends Node
class_name DoorInteraction

@export_category("Settings")
## Referência ao corpo físico da porta.
@export var door_ref: Node3D

## Define se a porta começa trancada.
@export var is_locked: bool = false

## ID do item aceito para destrancar.
@export var required_item_id: StringName = &""

@export_category("Label Settings")
var interact_label: String
@export var hover_label: String
@export var unlocked_label: String
@export var locked_door_label: String

@export_category("Sound Settings")
@export var locked_door_sound: AudioStreamPlayer3D

@export_category("Door Settings")
@export var auto_close: bool = false
@export var spring_stiffness: float = 1.0
@export var spring_damping: float = 3.0
@export var rest_angle: float = 0.0

@export_category("Drag Settings")
## Força que puxa o ponto da porta em direção à mão.
@export var grab_stiffness: float = 120.0

## Resistência ao movimento relativo entre a mão e a porta.
@export var grab_damping: float = 18.0

## Limite máximo da força aplicada.
@export var max_grab_force: float = 350.0

var auto_close_distance: float = 0.6
var can_interact: bool = true
var is_interacting: bool = false

var player_hand: Marker3D

# Posição do ponto agarrado no espaço local da porta.
var grabbed_door_local_position: Vector3 = Vector3.ZERO

# Posição do mesmo ponto no espaço local do PlayerHand.
var grabbed_hand_local_position: Vector3 = Vector3.ZERO

# Posição anterior do ponto acompanhado pela mão.
var previous_target_position: Vector3 = Vector3.ZERO

var has_grab_point: bool = false


func _ready() -> void:
	var rigid_body_door := door_ref as RigidBody3D

	if rigid_body_door == null:
		push_warning(
			"DoorInteraction: door_ref precisa apontar para um RigidBody3D."
		)
		return

	if is_locked:
		rigid_body_door.freeze = true
		rigid_body_door.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC


func _physics_process(_delta: float) -> void:
	if auto_close and not is_interacting:
		_auto_close()


func pre_interact() -> void:
	is_interacting = true
	has_grab_point = false


func interact() -> void:
	if not can_interact:
		return

	_try_interact()


## Chamado pelo InteractionController no início do arrasto.
## Recebe o ponto exato atingido pelo ShapeCast e o PlayerHand.
func begin_hold_interact(
	hit_position: Vector3,
	hand: Marker3D
) -> bool:
	if is_locked:
		return false

	var rigid_body_door := door_ref as RigidBody3D

	if not is_instance_valid(rigid_body_door):
		return false

	if rigid_body_door.freeze:
		return false

	if not is_instance_valid(hand):
		push_warning(
			"DoorInteraction: PlayerHand não foi encontrado."
		)
		return false

	player_hand = hand

	# Registra o mesmo ponto nos espaços locais da porta e da mão.
	grabbed_door_local_position = rigid_body_door.to_local(
		hit_position
	)

	grabbed_hand_local_position = player_hand.to_local(
		hit_position
	)

	previous_target_position = hit_position

	has_grab_point = true
	is_interacting = true

	return true


## Atualiza continuamente a força aplicada no ponto agarrado.
func hold_interact(delta: float) -> void:
	if not is_interacting or is_locked or not has_grab_point:
		return

	var rigid_body_door := door_ref as RigidBody3D

	if not is_instance_valid(rigid_body_door):
		return

	if rigid_body_door.freeze:
		return

	if not is_instance_valid(player_hand):
		return

	var safe_delta := maxf(delta, 0.0001)

	# Posição que o ponto agarrado deseja alcançar,
	# seguindo o movimento do PlayerHand.
	var target_position: Vector3 = player_hand.to_global(
		grabbed_hand_local_position
	)

	# Posição atual do ponto agarrado na porta.
	var anchor_position: Vector3 = rigid_body_door.to_global(
		grabbed_door_local_position
	)

	# Distância do ponto agarrado até o centro de massa.
	var anchor_offset: Vector3 = (
		anchor_position - rigid_body_door.global_position
	)

	# Velocidade real da porta exatamente no ponto agarrado.
	var anchor_velocity: Vector3 = (
		rigid_body_door.linear_velocity
		+ rigid_body_door.angular_velocity.cross(anchor_offset)
	)

	# Velocidade do ponto desejado, acompanhando a mão.
	var target_velocity: Vector3 = (
		target_position - previous_target_position
	) / safe_delta

	previous_target_position = target_position

	# Erro entre o ponto atual da porta e o ponto desejado.
	var position_error: Vector3 = (
		target_position - anchor_position
	)

	# Controle físico proporcional + amortecimento.
	var force: Vector3 = (
		position_error * grab_stiffness
		+ (target_velocity - anchor_velocity) * grab_damping
	)

	# Impede forças exageradas com movimentos rápidos do mouse.
	force = force.limit_length(max_grab_force)

	rigid_body_door.sleeping = false

	# Aplica a força no ponto agarrado, não no centro da porta.
	# Isso permite que a dobradiça produza a rotação.
	rigid_body_door.apply_force(force, anchor_offset)


func post_interact() -> void:
	is_interacting = false
	has_grab_point = false
	player_hand = null


## Interface contextual usada pelo ItemActionController.
func try_use_item(
	item_data: ItemData,
	player: Player,
	_item_instance: Node3D
) -> ItemUseResult:
	if not is_locked:
		return ItemUseResult.not_handled()

	if item_data == null:
		return ItemUseResult.not_handled()

	if (
		required_item_id.is_empty()
		or item_data.id != required_item_id
	):
		interact_label = locked_door_label

		if is_instance_valid(locked_door_sound):
			locked_door_sound.play()

		return ItemUseResult.failed(locked_door_label)

	interact_label = unlocked_label

	return ItemUseResult.completed(
		Callable(self, "_unlock_and_open").bind(player)
	)


func _try_interact() -> void:
	var rigid_body_door := door_ref as RigidBody3D

	if rigid_body_door == null:
		push_warning(
			"DoorInteraction: door_ref precisa apontar para um RigidBody3D."
		)
		return

	if not is_locked:
		interact_label = unlocked_label
	else:
		interact_label = locked_door_label

		rigid_body_door.freeze = true
		rigid_body_door.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC

		if is_instance_valid(locked_door_sound):
			locked_door_sound.play()


func _unlock_and_open(_player: Player) -> bool:
	var rigid_body_door := door_ref as RigidBody3D

	if not is_instance_valid(rigid_body_door):
		return false

	is_locked = false

	rigid_body_door.linear_velocity = Vector3.ZERO
	rigid_body_door.angular_velocity = Vector3.ZERO

	rigid_body_door.freeze = false
	rigid_body_door.sleeping = false

	interact_label = unlocked_label

	return true


func _auto_close() -> void:
	var rigid_body_door := door_ref as RigidBody3D

	if rigid_body_door == null or rigid_body_door.freeze:
		return

	if is_interacting:
		return

	if not is_instance_valid(Global.player):
		return

	var player_pos: Vector3 = Global.player.global_position
	var door_pos: Vector3 = rigid_body_door.global_position

	var door_pos_flat := Vector2(door_pos.x, door_pos.z)
	var player_pos_flat := Vector2(player_pos.x, player_pos.z)

	if door_pos_flat.distance_to(player_pos_flat) < auto_close_distance:
		return

	var angle := rigid_body_door.global_rotation.y
	var velocity := rigid_body_door.angular_velocity.y
	var target := deg_to_rad(rest_angle)

	var torque := (
		-(angle - target) * spring_stiffness
	) - (velocity * spring_damping)

	rigid_body_door.apply_torque(Vector3(0.0, torque, 0.0))
