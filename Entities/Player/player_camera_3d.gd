class_name PlayerCamera extends Camera3D

@export_category("Mouse Settings")
@export var mouse_sense := 0.2
@export_category("Camera Limits")
@export var cam_limit_down := -80.0
@export var cam_limit_up := 60.0
@export_category("Camera Smoothing Settings")
@export var camera_smooth_speed := 20.0
@export var head_smooth_speed := 20.0
@export_category("Bob Settings")
@export var bob_freq = 3.0
@export var bob_amp = 0.05
@export var bob_on_time = 0.0
@export var ZOOM_SPEED = 1.75
@onready var ANIMATION_PLAYER: AnimationPlayer = $"../../AnimationPlayer"

var target_head_rotation_y := 0.0
var target_camera_rotation_x := 0.0

@onready var head = get_parent()
@onready var player = $"../.."
func handle_mouse_motion(event: InputEventMouseMotion) -> void:
	target_head_rotation_y -= deg_to_rad(event.relative.x * mouse_sense)
	target_camera_rotation_x -= deg_to_rad(event.relative.y * mouse_sense)
	target_camera_rotation_x = clamp(target_camera_rotation_x, deg_to_rad(cam_limit_down), deg_to_rad(cam_limit_up))

func smooth_rotation(delta: float) -> void:
	head.rotation.y = lerp_angle(head.rotation.y, target_head_rotation_y, delta * head_smooth_speed)
	rotation.x = lerp_angle(rotation.x, target_camera_rotation_x, delta * camera_smooth_speed)

func handle_zoom() -> void:
	if Input.is_action_just_pressed("right_click"):
		ANIMATION_PLAYER.play("camera_zoom", -1, ZOOM_SPEED)
	if Input.is_action_just_released("right_click"):
		ANIMATION_PLAYER.play("camera_zoom", -1, -ZOOM_SPEED, true)

# Substitua as variáveis e funções de bob por isto:

var _step_cooldown: float = 0.0
const MIN_STEP_INTERVAL: float = 0.15
var _stepped_this_cycle: bool = false

func handle_bob(time: float, delta: float) -> Vector3:
	var pos = Vector3.ZERO

	var sine_value = sin(time * bob_freq)
	pos.y = sine_value * bob_amp

	if _step_cooldown > 0.0:
		_step_cooldown -= delta

	if sine_value <= -0.95:
		if not _stepped_this_cycle and _step_cooldown <= 0.0:
			player.play_step_sounds()
			_step_cooldown = MIN_STEP_INTERVAL
			_stepped_this_cycle = true
	else:
		_stepped_this_cycle = false

	return pos

func _reset_bob_state() -> void:
	_step_cooldown = 0.0
	_stepped_this_cycle = false
