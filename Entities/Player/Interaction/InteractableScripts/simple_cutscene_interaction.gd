extends Node
class_name SimpleCutsceneInteraction

@export_category("Settings")
@export var can_interact: bool = true
@export var transition_duration: float = 0.8

@export_category("Label Settings")
@export var hover_label: String
@export var click_label: String
@export var target_position: Marker3D

var interact_label: String = ""
var player: Player

var is_watching: bool = false
var is_transitioning: bool = false

var previous_camera_transform: Transform3D
var previous_can_move: bool = true

var camera_tween: Tween


func _ready() -> void:
	player = Global.player
	# Roda DEPOIS do script do player, então a última palavra é nossa
	process_priority = 1000
	process_physics_priority = 1000


func _process(_delta: float) -> void:
	# Depois da animação, trava a câmera exatamente no target
	if is_watching and not is_transitioning and player and target_position:
		player.camera.global_transform = _clean(target_position.global_transform)


func pre_interact() -> void:
	pass


func interact() -> void:
	if player == null:
		push_warning("Player não encontrado.")
		return
	if target_position == null:
		push_warning("Target Position não configurado.")
		return
	if is_transitioning:
		return

	if not is_watching:
		previous_camera_transform = player.camera.global_transform
		previous_can_move = player.can_move
		player.can_move = false

		# Solta a câmera da hierarquia do player (corpo/head não interferem)
		player.camera.top_level = true
		player.camera.global_transform = previous_camera_transform

		is_watching = true
		interact_label = click_label
		animate_camera(target_position.global_transform)
	else:
		is_watching = false
		interact_label = hover_label
		animate_camera(previous_camera_transform)


func animate_camera(target: Transform3D) -> void:
	is_transitioning = true

	if camera_tween and camera_tween.is_running():
		camera_tween.kill()

	var start := _clean(player.camera.global_transform)
	var end := _clean(target)

	var start_quat := start.basis.get_rotation_quaternion()
	var end_quat := end.basis.get_rotation_quaternion()

	camera_tween = create_tween()
	camera_tween.set_trans(Tween.TRANS_SINE)
	camera_tween.set_ease(Tween.EASE_IN_OUT)

	camera_tween.tween_method(
		func(value: float) -> void:
			player.camera.global_transform = Transform3D(
				Basis(start_quat.slerp(end_quat, value)),
				start.origin.lerp(end.origin, value)
			),
		0.0,
		1.0,
		transition_duration
	)

	camera_tween.finished.connect(
		func() -> void:
			player.camera.global_transform = end
			is_transitioning = false

			if not is_watching:
				# Devolve a câmera para a hierarquia do player
				player.camera.top_level = false
				player.camera.global_transform = end
				player.can_move = previous_can_move
	)


# Remove escala do transform (evita rotação estranha com Marker3D escalado)
func _clean(t: Transform3D) -> Transform3D:
	return Transform3D(t.basis.orthonormalized(), t.origin)


func post_interact() -> void:
	pass
