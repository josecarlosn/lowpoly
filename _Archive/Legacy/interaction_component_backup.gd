extends Node


enum InteractionType {
	DEFAULT,
	DOOR,
	NOTE
}

@export var object_ref: Node3D
@export var interaction_type: InteractionType = InteractionType.DEFAULT
var can_interact: bool = true
var is_interacting: bool = false

var player_hand: Marker3D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
func preInteract() -> void:
	is_interacting = true
	match interaction_type:
		InteractionType.DEFAULT:
			player_hand = Global.player.hand

func Interact() -> void:
	if not can_interact:
		return
	match interaction_type:
		InteractionType.DEFAULT:
			_default_interaction()
		InteractionType.DOOR:
			_door_interaction()

func postInteract() -> void:
	is_interacting = false
	
func _default_interaction() -> void:
	var object_current_position: Vector3 = object_ref.global_transform.origin
	var player_hand_position: Vector3 = player_hand.global_transform.origin
	var object_distance: Vector3 = player_hand_position - object_current_position
	
	var rigid_body: RigidBody3D = object_ref as RigidBody3D
	if rigid_body:
		rigid_body.set_linear_velocity(object_distance * (5.0/rigid_body.mass))

func _door_interaction() -> void:
	var object_current_position: Vector3 = object_ref.global_transform.origin
	var player_hand_position: Vector3 = player_hand.global_transform.origin
	var object_distance: Vector3 = player_hand_position - object_current_position
	
	var rigid_body: RigidBody3D = object_ref as RigidBody3D
	if rigid_body:
		rigid_body.set_linear_velocity(object_distance * (5.0/rigid_body.mass))
	
	
