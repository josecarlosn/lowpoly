
class_name EquipmentController
extends Node

@export var hand_anchor: Node3D
@export var player_camera: Camera3D

@export_group("Animação de Equipar")
@export var equip_offset: Vector3 = Vector3(0, -0.4, 0)
@export var equip_duration: float = 0.25
@export var unequip_duration: float = 0.20

@export_group("Item Sway")
@export var sway_strength: float = 2.0
@export var sway_smoothness: float = 8.0

var current_item: ItemData
var equipped_instance: Node3D
var animation: Tween
var is_transitioning: bool = false

var base_item_rotation: Vector3
var smoothed_camera_rotation: Vector3


func _ready() -> void:
	if player_camera != null:
		smoothed_camera_rotation = player_camera.global_rotation


func equip_item(item_data: ItemData) -> void:
	if item_data == null or is_transitioning:
		return

	if item_data.hand_scene_path.is_empty():
		push_warning("Este item não possui cena para a mão.")
		return

	if hand_anchor == null:
		push_warning("O hand_anchor não foi configurado.")
		return

	var packed_scene := load(item_data.hand_scene_path) as PackedScene

	if packed_scene == null:
		push_warning("Não foi possível carregar a cena da mão.")
		return

	var instance := packed_scene.instantiate()
	var new_instance := instance as Node3D

	if new_instance == null:
		instance.free()
		push_warning("A cena equipada precisa ter um Node3D como raiz.")
		return

	# Se outro item estiver equipado, anima sua saída primeiro.
	if is_instance_valid(equipped_instance):
		is_transitioning = true
		_play_unequip_animation()

		await animation.finished

		if is_instance_valid(equipped_instance):
			equipped_instance.queue_free()

		equipped_instance = null
		current_item = null
		is_transitioning = false

	# Cria o novo item.
	equipped_instance = new_instance
	hand_anchor.add_child(equipped_instance)
	current_item = item_data

	var target_position := equipped_instance.position
	base_item_rotation = equipped_instance.rotation

	if player_camera != null:
		smoothed_camera_rotation = player_camera.global_rotation

	# Começa abaixo da posição normal.
	equipped_instance.position = target_position + equip_offset

	is_transitioning = true

	animation = create_tween()
	animation.set_trans(Tween.TRANS_SINE)
	animation.set_ease(Tween.EASE_OUT)

	animation.tween_property(
		equipped_instance,
		"position",
		target_position,
		equip_duration
	)

	await animation.finished
	is_transitioning = false


func unequip_item() -> void:
	if is_transitioning:
		return

	if not is_instance_valid(equipped_instance):
		current_item = null
		return

	is_transitioning = true

	_play_unequip_animation()
	await animation.finished

	if is_instance_valid(equipped_instance):
		equipped_instance.queue_free()

	equipped_instance = null
	current_item = null
	base_item_rotation = Vector3.ZERO
	is_transitioning = false


# Remove o modelo da mão imediatamente ao dropar.
func remove_equipped_for_drop(item_data: ItemData) -> bool:
	if is_transitioning:
		return false

	if current_item != item_data:
		return false

	if not is_instance_valid(equipped_instance):
		return false

	equipped_instance.queue_free()

	equipped_instance = null
	current_item = null
	base_item_rotation = Vector3.ZERO

	return true


func _play_unequip_animation() -> void:
	animation = create_tween()
	animation.set_trans(Tween.TRANS_SINE)
	animation.set_ease(Tween.EASE_IN)

	animation.tween_property(
		equipped_instance,
		"position",
		equipped_instance.position + equip_offset,
		unequip_duration
	)


func _process(delta: float) -> void:
	if not is_instance_valid(equipped_instance):
		return

	if player_camera == null or is_transitioning:
		return

	var current_camera_rotation := player_camera.global_rotation
	var weight := 1.0 - exp(-sway_smoothness * delta)

	smoothed_camera_rotation.x = lerp_angle(
		smoothed_camera_rotation.x,
		current_camera_rotation.x,
		weight
	)

	smoothed_camera_rotation.y = lerp_angle(
		smoothed_camera_rotation.y,
		current_camera_rotation.y,
		weight
	)

	smoothed_camera_rotation.z = lerp_angle(
		smoothed_camera_rotation.z,
		current_camera_rotation.z,
		weight
	)

	var camera_lag := Vector3(
		angle_difference(
			current_camera_rotation.x,
			smoothed_camera_rotation.x
		),
		angle_difference(
			current_camera_rotation.y,
			smoothed_camera_rotation.y
		),
		angle_difference(
			current_camera_rotation.z,
			smoothed_camera_rotation.z
		)
	)

	var sway_offset := Vector3(
		camera_lag.x,
		camera_lag.y,
		-camera_lag.y * 0.5
	) * sway_strength

	var target_rotation := base_item_rotation + sway_offset

	equipped_instance.rotation = equipped_instance.rotation.lerp(
		target_rotation,
		weight
	)
