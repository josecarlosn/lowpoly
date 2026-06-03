extends Node
class_name DoorInteraction

@export_category("Settings")
@export var door_ref: Node3D
@export var is_locked: bool = false
@export var key_id: String

@export_category("Label Settings")
@export var label: String
@export var locked_door_label: String
@export var description: String

@export_category("Sound Settings")
@export var locked_door_sound: AudioStreamPlayer3D

var can_interact: bool = true
var is_interacting: bool = false
var player_hand: Marker3D

func _ready() -> void:
	var rigid_body_door: RigidBody3D = door_ref as RigidBody3D
	if is_locked:
		if rigid_body_door:
			rigid_body_door.freeze = true
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
		var door_current_position: Vector3 = door_ref.global_transform.origin
		var player_hand_position: Vector3 = player_hand.global_transform.origin
		var door_distance: Vector3 = player_hand_position - door_current_position
		var rigid_body_door: RigidBody3D = door_ref as RigidBody3D
		rigid_body_door.freeze = false

		if rigid_body_door:
			rigid_body_door.set_linear_velocity(door_distance * (5.0/rigid_body_door.mass))
	else: #Locked door!
		var rigid_body_door: RigidBody3D = door_ref as RigidBody3D
		rigid_body_door.freeze = true
		rigid_body_door.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
