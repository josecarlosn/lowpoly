extends Node
class_name DoorInteraction

@export var label: String
@export var label_if_door_is_locked: String
@export var sound_if_door_is_locked: AudioStreamPlayer3D
@export var description: String
@export var is_locked: bool = false
@export var key_id: String

@export var object_ref: Node3D

var can_interact: bool = true
var is_interacting: bool = false

var player_hand: Marker3D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var rigid_body: RigidBody3D = object_ref as RigidBody3D
	if is_locked:
		if rigid_body:
			rigid_body.freeze = true
func preInteract() -> void:
	is_interacting = true
	player_hand = Global.player.hand

func Interact() -> void:
	if not can_interact:
		return
	interact()

func postInteract() -> void:
	is_interacting = false
	
func interact() -> void:
	var object_current_position: Vector3 = object_ref.global_transform.origin
	var player_hand_position: Vector3 = player_hand.global_transform.origin
	var object_distance: Vector3 = player_hand_position - object_current_position
	
	var rigid_body: RigidBody3D = object_ref as RigidBody3D
	if is_locked:
		if rigid_body:
			rigid_body.freeze = true
	else:	
		if rigid_body:
			rigid_body.freeze = false
			rigid_body.set_linear_velocity(object_distance * (5.0/rigid_body.mass))

	
