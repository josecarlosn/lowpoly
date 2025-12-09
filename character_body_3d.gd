extends CharacterBody3D

@export_category("Player Settings")
@export var SPEED := 4.0
@export var JUMP_VELOCITY := 3.5

@export_category("Mouse Settings")
@export var mouse_sense := 0.1

@export_category("Camera Limits")
@export var cam_limit_down := -80.0
@export var cam_limit_up := 60.0
var cam_ver = 0.0

@onready var camera = $head/Camera3D
@onready var head = $head
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		
		head.rotate_y(deg_to_rad(-event.relative.x * mouse_sense))
		camera.rotate_x(deg_to_rad(-event.relative.y * mouse_sense))
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(cam_limit_down), deg_to_rad(cam_limit_up))
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized() #adicionei o head na frente do transform pra andar na direção da camera
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
