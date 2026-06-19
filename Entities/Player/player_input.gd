class_name PlayerInput extends Node
@onready var player: CharacterBody3D = get_parent()
@onready var jump: AudioStreamPlayer3D = $"../PlayerSounds/Jump"

var direction := Vector3.ZERO
var is_sprinting := false
var jump_requested := false
var crouch_just_pressed := false
var is_interacting:bool
var in_inventory := false # Começa fechado (false)
var lamp_request := false

func poll(head_basis: Basis) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	direction = (head_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	is_sprinting = Input.is_action_pressed("sprint")
	jump_requested = Input.is_action_just_pressed("jump")
	crouch_just_pressed = Input.is_action_just_pressed("crouch")
	is_interacting = Input.is_action_pressed("primary")
	lamp_request = Input.is_action_just_pressed("lamp")
	
	# SE apertar o botão, inverte o estado atual (se era false vira true, se era true vira false)
	if Input.is_action_just_pressed("inventory"):
		player.can_move = !player.can_move
		in_inventory = !in_inventory
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	

		
