extends CharacterBody3D
class_name Player

const FORCA_EMPURRAO = 1.0
@export_category("Player Settings")
@export var SPRINT_SPEED := 4.0
@export var DEFAULT_SPEED := 2
@export var CROUCH_SPEED := 1
@export var JUMP_VELOCITY := 2.5

@export_range(1, 10, 0.1) var CROUCH_ANIMATION_SPEED = 5.0
var SPEED := DEFAULT_SPEED

var _is_crouching : bool = false
var _is_sprinting : bool = false
var _can_sprint : bool = true
var _can_jump : bool = true
var can_move : bool = true
var is_paused = false
var _was_on_floor: bool = true
@onready var camera: PlayerCamera = $head/Camera3D
@onready var head = $head
@onready var player_movement: PlayerMovement = $PlayerMovement
@onready var player_input: PlayerInput = $PlayerInput  # ← novo
@onready var detected = null
@onready var state_machine: StateMachine = $StateMachine

@onready var wood_step: AudioStreamPlayer3D = $PlayerSounds/WoodStep
@onready var floor_type_ray: RayCast3D = $FloorTypeRay


func _ready() -> void:
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(55)
	safe_margin = 0.005
	Global.player = self
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if can_move:
		if event is InputEventMouseMotion:
			camera.handle_mouse_motion(event)
		if Input.is_action_just_pressed("crouch"):
			toggle_crouch()
		if Input.is_action_just_pressed("jump"):
			toggle_jump()
		if Input.is_action_pressed("sprint"):
			_is_sprinting = true	
			handle_sprint()
		if Input.is_action_just_released("sprint"):
			_is_sprinting = false	
			handle_sprint()
	camera.handle_zoom()
	
	
	if Input.is_action_just_pressed("ui_cancel"):
		is_paused = !is_paused
		if is_paused:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	camera.smooth_rotation(delta)
	
	var just_landed = not _was_on_floor and is_on_floor()
	if just_landed:
		play_step_sounds()

	_was_on_floor = is_on_floor()
	#print("Pode correr? >", _can_sprint)
	#print("Está correndo? > ", _is_sprinting)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	# move_and_slide() saiu daqui — cada estado chama o seu
	if _is_crouching == false and can_move:
		camera.bob_on_time += delta * velocity.length() * float(is_on_floor())
		head.transform.origin = camera.handle_bob(camera.bob_on_time)
	for i in get_slide_collision_count():
		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()
		if objeto is RigidBody3D:
			var direcao_empurrao = colisao.get_normal() * -1
			objeto.apply_central_impulse(direcao_empurrao * FORCA_EMPURRAO)

func toggle_crouch():
	_is_crouching = !_is_crouching
	if _is_crouching:
		_can_sprint = false
		_can_jump = false
		_is_sprinting = false
		SPEED = CROUCH_SPEED
		camera.ANIMATION_PLAYER.play("crouch", -1, CROUCH_ANIMATION_SPEED)
	else:
		_can_sprint = true
		_can_jump = true
		camera.ANIMATION_PLAYER.play("crouch", -1, -CROUCH_ANIMATION_SPEED, true)
		SPEED = DEFAULT_SPEED
func handle_sprint():
	if _is_sprinting == true and _can_sprint == true:
		SPEED = SPRINT_SPEED
	else:
		if _is_crouching == true:
			SPEED = CROUCH_SPEED
		else:
			SPEED = DEFAULT_SPEED
func toggle_jump():
	if is_on_floor() and _can_jump:
		velocity.y = JUMP_VELOCITY


func play_step_sounds():
	if floor_type_ray.is_colliding():
		var floor = floor_type_ray.get_collider()
		if floor.is_in_group("wood_floor"):
			wood_step.play()
