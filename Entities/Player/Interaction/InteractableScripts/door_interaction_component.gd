extends Node
class_name DoorInteraction

@export_category("Settings")
## Referência do corpo físico da porta.
@export var door_ref: Node3D
## Define se a porta começa trancada.
@export var is_locked: bool = false
## ID do item aceito para destrancar. Pode ser chave, pé de cabra ou outro item.
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
## Define quão rápido a porta volta para sua posição de origem.
@export var spring_stiffness: float = 1.0
## Controla a resistência e o balanço do movimento da porta.
@export var spring_damping: float = 3.0
## Corrige o ângulo da porta caso o ângulo original não seja o esperado.
@export var rest_angle: float = 0.0
@export var FORCA_ABERTURA: float = 3.0

var auto_close_distance: float = 0.6
var can_interact: bool = true
var is_interacting: bool = false
var player_hand: Marker3D


func _ready() -> void:
	var rigid_body_door := door_ref as RigidBody3D
	if is_locked and rigid_body_door != null:
		rigid_body_door.freeze = true


func _physics_process(_delta: float) -> void:
	if auto_close:
		_auto_close()


func pre_interact() -> void:
	is_interacting = true
	if is_instance_valid(Global.player):
		player_hand = Global.player.hand


func interact() -> void:
	if not can_interact:
		return
	_try_interact()


func post_interact() -> void:
	is_interacting = false


## Interface contextual genérica usada pelo ItemActionController.
## O alvo escolhe qual ID aceita; o item não precisa conhecer portas.
func try_use_item(
	item_data: ItemData,
	player: Player,
	_item_instance: Node3D
) -> ItemUseResult:
	if not is_locked:
		return ItemUseResult.not_handled()

	if item_data == null:
		return ItemUseResult.not_handled()

	if required_item_id.is_empty() or item_data.id != required_item_id:
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
		push_warning("DoorInteraction: door_ref precisa apontar para um RigidBody3D.")
		return

	if not is_locked:
		interact_label = unlocked_label
		_open_door(Global.player)
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
	interact_label = unlocked_label

	print("Velocidade no momento do destrancamento:")
	print("Linear: ", rigid_body_door.linear_velocity)
	print("Angular: ", rigid_body_door.angular_velocity)

	return true


func _open_door(player: Player) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(door_ref):
		return false

	var rigid_body_door := door_ref as RigidBody3D
	if rigid_body_door == null:
		return false

	var hand := player.hand
	if not is_instance_valid(hand):
		return false

	# Porta trancada não pode ser aberta.
	if is_locked:
		return false

	# Mantém o comportamento original de abertura ao segurar.
	var door_distance := hand.global_position - door_ref.global_position
	print("Posição antes de descongelar: ", rigid_body_door.global_position)
	print("Rotação antes de descongelar: ", rigid_body_door.global_rotation)
	rigid_body_door.freeze = false
	print("Posição depois de descongelar: ", rigid_body_door.global_position)
	print("Rotação depois de descongelar: ", rigid_body_door.global_rotation)
	rigid_body_door.set_linear_velocity(
		door_distance * (5.0 / maxf(rigid_body_door.mass, 0.001))
	)

	return true




func _auto_close() -> void:
	var rigid_body_door := door_ref as RigidBody3D
	if rigid_body_door == null or rigid_body_door.freeze:
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
	var torque := (-(angle - target) * spring_stiffness) - (velocity * spring_damping)
	rigid_body_door.apply_torque(Vector3(0, torque, 0))
