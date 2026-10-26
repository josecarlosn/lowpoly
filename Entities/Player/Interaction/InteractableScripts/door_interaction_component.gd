extends Node
class_name DoorInteraction

@export_category("Settings")
##Referência do objeto
@export var door_ref: Node3D
##Define se está trancada ou não
@export var is_locked: bool = false
##Define qual o ID da chave que abre essa porta
@export var key_id: String

@export_category("Label Settings")
var interact_label: String
@export var hover_label: String
@export var unlocked_label: String # Inútil por enquando
@export var locked_door_label: String

@export_category("Sound Settings")
@export var locked_door_sound: AudioStreamPlayer3D

@export_category("Door Settings")
@export var auto_close: bool = false
##Define quão rápido a porta volta para sua posição de origem
@export var spring_stiffness: float = 1.0
##Controla a resistência e o balanço do movimento da porta.
@export var spring_damping: float = 3.0
##Corrige o ângulo da porta caso o ângulo original não seja o esperado.
@export var rest_angle: float = 0.0  # em graus

@export var FORCA_ABERTURA: float = 3.0
var auto_close_distance: float = 0.6
var can_interact: bool = true
var is_interacting: bool = false
var player_hand: Marker3D

func _ready() -> void:
	var rigid_body_door: RigidBody3D = door_ref as RigidBody3D
	if is_locked:
		if rigid_body_door:
			rigid_body_door.freeze = true
func _physics_process(_delta: float) -> void:

	if auto_close:
		_auto_close()

func pre_interact() -> void:
	is_interacting = true
	player_hand = Global.player.hand
func interact() -> void:
	if not can_interact:
		return
	_try_interact()
func post_interact() -> void:
	is_interacting = false

func _try_interact() -> void:
	if not is_locked: #Unlocked door!
		interact_label = unlocked_label
		var door_current_position: Vector3 = door_ref.global_transform.origin
		var player_hand_position: Vector3 = player_hand.global_transform.origin
		var door_distance: Vector3 = player_hand_position - door_current_position
		var rigid_body_door: RigidBody3D = door_ref as RigidBody3D
		rigid_body_door.freeze = false

		if rigid_body_door:
			rigid_body_door.set_linear_velocity(door_distance * (5.0/rigid_body_door.mass))
	else: #Locked door!
		interact_label = locked_door_label
		var rigid_body_door: RigidBody3D = door_ref as RigidBody3D
		rigid_body_door.freeze = true
		rigid_body_door.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC	


func _auto_close():
	var rigid_body_door: RigidBody3D = door_ref as RigidBody3D
	if not rigid_body_door or rigid_body_door.freeze:
		return

	var player_pos = Global.player.global_transform.origin
	var door_pos = rigid_body_door.global_transform.origin

	var door_pos_flat = Vector2(door_pos.x, door_pos.z)
	var player_pos_flat = Vector2(player_pos.x, player_pos.z)
	if door_pos_flat.distance_to(player_pos_flat) < auto_close_distance:
		return

	var angle = rigid_body_door.global_rotation.y
	var vel = rigid_body_door.angular_velocity.y
	var target = deg_to_rad(rest_angle)
	var torque = (-(angle - target) * spring_stiffness) - (vel * spring_damping)
	rigid_body_door.apply_torque(Vector3(0, torque, 0))
