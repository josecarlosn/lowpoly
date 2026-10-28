class_name PlayerInput extends Node
@onready var player: CharacterBody3D = get_parent()
@onready var jump: AudioStreamPlayer3D = $"../PlayerSounds/Jump"

var direction := Vector3.ZERO
var is_sprinting := false
var jump_requested := false
var crouch_just_pressed := false
var is_interacting:bool

var lamp_request := false # Vai ser desnecessário
var drop_request := false	
var equip_request := false
var selected_slot_request := -1

var debug_request := false

var in_inventory := false # Começa fechado (false)
var in_debug := false

func poll(head_basis: Basis) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	direction = (head_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	is_sprinting = Input.is_action_pressed("sprint")
	jump_requested = Input.is_action_just_pressed("jump")
	crouch_just_pressed = Input.is_action_just_pressed("crouch")
	
	is_interacting = Input.is_action_pressed("primary") and not in_inventory
	
	drop_request = Input.is_action_just_pressed("drop")
	equip_request = Input.is_action_just_pressed("equip") and  in_inventory
		
	lamp_request = Input.is_action_just_pressed("lamp")
	debug_request = Input.is_action_just_pressed("debug")
	

	# SE apertar o botão, inverte o estado atual (se era false vira true, se era true vira false)
	if Input.is_action_just_pressed("inventory"):
		player.can_move = !player.can_move
		in_inventory = !in_inventory
	
	selected_slot_request = -1
	for i in range(5):
		var action_name := "slot_" + str(i + 1)

		if Input.is_action_just_pressed(action_name):
			selected_slot_request = i
			break	
	if Input.is_action_just_pressed("drop"):
		drop_request = true 		
	if Input.is_action_just_pressed("debug"):
		in_debug = !in_debug


	
