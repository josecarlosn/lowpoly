extends CharacterBody3D

@export_category("Player Settings")
@export var SPRINT_SPEED := 4.0
@export var DEFAULT_SPEED := 2.5
@export var CROUCH_SPEED := 1
var SPEED := DEFAULT_SPEED
@export_range(5, 10, 0.1) var CROUCH_ANIMATION_SPEED = 5.0
@export var ZOOM_SPEED = 5.0

@export_category("Mouse Settings")
@export var mouse_sense := 0.2

@export_category("Camera Limits")
@export var cam_limit_down := -80.0
@export var cam_limit_up := 60.0
var cam_ver = 0.0
@export_category("Bob Settings")
var bob_freq = 4.0
var bob_amp = 0.05
var bob_on_time = 0.0

@export var ANIMATION_PLAYER: AnimationPlayer
@onready var camera = $head/Camera3D
@onready var head = $head

var _is_crouching : bool = false 
var _is_sprinting : bool = false
var _can_sprint : bool = true
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
func _input(event: InputEvent) -> void:
	#Mouse movement
	if event is InputEventMouseMotion:
		head.rotate_y(deg_to_rad(-event.relative.x * mouse_sense))
		camera.rotate_x(deg_to_rad(-event.relative.y * mouse_sense))
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(cam_limit_down), deg_to_rad(cam_limit_up))
	#Camera Zoom
	if Input.is_action_just_pressed("right_click") == true:
		ANIMATION_PLAYER.play("camera_zoom",-1, ZOOM_SPEED)
	if Input.is_action_just_released("right_click") == true:
		ANIMATION_PLAYER.play("camera_zoom",-1, -ZOOM_SPEED, true)
	
	#Esc 
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#Crouch	
	if Input.is_action_just_pressed("crouch"):
		toggle_crouch()
	#if Input.is_action_just_pressed("crouch") == true:
		#toggle_crouch()
		#ANIMATION_PLAYER.play("crouch",-1, CROUCH_ANIMATION_SPEED)
	#if Input.is_action_just_released("crouch") == true:
		#toggle_crouch()
		#ANIMATION_PLAYER.play("crouch",-1, -CROUCH_ANIMATION_SPEED, true)
	#Srpint
	if Input.is_action_pressed("sprint") == true:
		_is_sprinting = true
		if _can_sprint == true:
			toggle_sprint()	
	else: 
		_is_sprinting = false
		toggle_sprint()	

func _process(delta: float) -> void:
	
	#Gravity-------------------------------------------------------------------------------------------
	if not is_on_floor():
		velocity += get_gravity() * delta
	#Player Movement-----------------------------------------------------------------------------------
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized() #adicionei o head na frente do transform pra andar na direção da camera
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	move_and_slide()
	
	##BOB Camera---------------------------------------------------------------------------------------
	if _is_crouching == false:
		bob_on_time += delta * velocity.length() * float(is_on_floor())
		head.transform.origin = handle_bob(bob_on_time)
	
#Bob func
func handle_bob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_freq) * bob_amp
	return pos
#Crouch func		
func toggle_crouch():
	_is_crouching = !_is_crouching	
	if _is_crouching:
		_can_sprint = false
		_is_sprinting = false
		SPEED = CROUCH_SPEED
		ANIMATION_PLAYER.play("crouch",-1, CROUCH_ANIMATION_SPEED)
	else:
		_can_sprint = true
		ANIMATION_PLAYER.play("crouch",-1, -CROUCH_ANIMATION_SPEED, true)
		SPEED = DEFAULT_SPEED
#Sprint func		
func toggle_sprint():
	if _is_sprinting == true:	
		SPEED = SPRINT_SPEED
	else:
		if _is_crouching == true:
			SPEED = CROUCH_SPEED
		else:
			SPEED = DEFAULT_SPEED	
