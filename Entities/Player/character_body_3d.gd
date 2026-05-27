extends CharacterBody3D

class_name Player
const FORCA_EMPURRAO = 1.0  # força aplicada no objeto
@export_category("Player Settings")
@export var SPRINT_SPEED := 6.0
@export var DEFAULT_SPEED := 3.5
@export var CROUCH_SPEED := 1
@export var JUMP_VELOCITY := 2.5
var SPEED := DEFAULT_SPEED
@export_range(1, 10, 0.1) var CROUCH_ANIMATION_SPEED = 5.0
@export var ZOOM_SPEED = 5.0
@export_category("Mouse Settings")
@export var mouse_sense := 0.2
@export_category("Camera Limits")
@export var cam_limit_down := -80.0
@export var cam_limit_up := 60.0
@export_category("Camera Smoothing Settings")
@export var camera_smooth_speed := 20.0
@export var head_smooth_speed := 20.0

var target_head_rotation_y := 0.0
var target_camera_rotation_x := 0.0
var cam_ver = 0.0
@export_category("Bob Settings")
@export var bob_freq = 2.0
@export var bob_amp = 0.1
@export var bob_on_time = 0.0
@export var ANIMATION_PLAYER: AnimationPlayer
@onready var camera = $head/Camera3D
@onready var head = $head
var _is_crouching : bool = false
var _is_sprinting : bool = false
var _can_sprint : bool = true
var _can_jump : bool = true
var can_move : bool = true
var is_paused = false

@onready var detected = null

@onready var state_machine: StateMachine = $StateMachine

func _ready() -> void:
	target_head_rotation_y = head.rotation.y
	target_camera_rotation_x = camera.rotation.x
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(55)
	safe_margin = 0.005
	Global.player = self
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if can_move:
		# Mouse movement
		if event is InputEventMouseMotion:
			target_head_rotation_y -= deg_to_rad(event.relative.x * mouse_sense)
			target_camera_rotation_x -= deg_to_rad(event.relative.y * mouse_sense)
			target_camera_rotation_x = clamp(target_camera_rotation_x, deg_to_rad(cam_limit_down), deg_to_rad(cam_limit_up))
		# Crouch
		if Input.is_action_just_pressed("crouch"):
			toggle_crouch()
		# Jump
		if Input.is_action_just_pressed("jump"):
			toggle_jump()
		# Sprint
		if Input.is_action_pressed("sprint") == true:
			_is_sprinting = true
			if _can_sprint == true:
				toggle_sprint()
		else:
			_is_sprinting = false
			toggle_sprint()
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
	else: pass
	# Camera Zoom
	if Input.is_action_just_pressed("right_click") == true:
		ANIMATION_PLAYER.play("camera_zoom",-1, ZOOM_SPEED)
	if Input.is_action_just_released("right_click") == true:
		ANIMATION_PLAYER.play("camera_zoom",-1, -ZOOM_SPEED, true)
	# Esc
	if Input.is_action_just_pressed("ui_cancel"):
		is_paused = !is_paused
		if is_paused:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	# Smooth camera movement
	head.rotation.y = lerp_angle(head.rotation.y, target_head_rotation_y, delta * head_smooth_speed)
	camera.rotation.x = lerp_angle(camera.rotation.x, target_camera_rotation_x, delta * camera_smooth_speed)

func _physics_process(delta):
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	# Player Movement
	if can_move:
		move_and_slide()
	# BOB Camera
	if _is_crouching == false:
		if can_move:
			bob_on_time += delta * velocity.length() * float(is_on_floor())
			head.transform.origin = handle_bob(bob_on_time)
	# Empurrar objetos
	for i in get_slide_collision_count():
		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()
		if objeto is RigidBody3D:  # ← era RigidBody2D, agora 3D
			var direcao_empurrao = colisao.get_normal() * -1
			objeto.apply_central_impulse(direcao_empurrao * FORCA_EMPURRAO)
# Bob func
func handle_bob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_freq) * bob_amp
	return pos

# Crouch func
func toggle_crouch():
	_is_crouching = !_is_crouching
	if _is_crouching:
		_can_sprint = false
		_can_jump = false
		_is_sprinting = false
		SPEED = CROUCH_SPEED
		ANIMATION_PLAYER.play("crouch",-1, CROUCH_ANIMATION_SPEED)
	else:
		_can_sprint = true
		_can_jump = true
		ANIMATION_PLAYER.play("crouch",-1, -CROUCH_ANIMATION_SPEED, true)
		SPEED = DEFAULT_SPEED

# Sprint func
func toggle_sprint():
	if _is_sprinting == true:
		SPEED = SPRINT_SPEED
	else:
		if _is_crouching == true:
			SPEED = CROUCH_SPEED
		else:
			SPEED = DEFAULT_SPEED

# Jump func
func toggle_jump():
	if is_on_floor() and _can_jump:
		velocity.y = JUMP_VELOCITY
