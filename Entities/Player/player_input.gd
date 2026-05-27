class_name PlayerInput extends Node

var direction := Vector3.ZERO
var is_sprinting := false
var jump_requested := false
var crouch_just_pressed := false

func poll(head_basis: Basis) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	direction = (head_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	is_sprinting = Input.is_action_pressed("sprint")
	jump_requested = Input.is_action_just_pressed("jump")
	crouch_just_pressed = Input.is_action_just_pressed("crouch")
