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
@export var bob_freq = 2.0
@export var bob_amp = 0.1
@export var bob_on_time = 0.0
@export var ZOOM_SPEED = 5.0
@onready var ANIMATION_PLAYER: AnimationPlayer = $"../../AnimationPlayer"

var target_head_rotation_y := 0.0
var target_camera_rotation_x := 0.0

@onready var head = get_parent()

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

var _prev_bob_y: float = 0.0
var _was_descending: bool = false
var _step_count: int = 0  # <- aqui fora


func handle_bob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_freq) * bob_amp

	var descending = pos.y < _prev_bob_y
	if _was_descending and not descending:
		_step_count += 1
		print("step", _step_count)

	_was_descending = descending
	_prev_bob_y = pos.y
	return pos


func _reset_bob_state() -> void:
	_prev_bob_y = 0.0
	_was_descending = false
