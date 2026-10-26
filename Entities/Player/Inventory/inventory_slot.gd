extends Control
class_name InventorySlot

@onready var icon: TextureRect = %InventoryTextureRect
@onready var num_slot: Label = %NumSlot
@onready var viewport_container: SubViewportContainer = $SubViewportContainer
@onready var model_pivot: Node3D = %Pivot

var slot_title: String
var slot_description: String

var inventory_slot_id: int = -1
var empty_icon: Texture = preload("uid://ckirht210g37o")
var slot_filled: bool = false
var slot_data: ItemData

var _model: Node3D

signal ont_item_swapped(from_slot_id: int, to_slot_id: int)
signal on_double_clicked(slot_id: int)
signal on_item_right_clicked(slot_id: int)

func _ready() -> void:
	icon.texture = empty_icon
	viewport_container.visible = false

func _process(delta: float) -> void:
	if _model:
		model_pivot.rotate_y(delta * 1.2)   # gira devagar

# fill_slot é chamado no pickup_item do inventory_controller.gd
func fill_slot(item_data: ItemData) -> void:
	slot_data = item_data
	if slot_data == null:
		clear_slot()
		return
	slot_filled = true
	slot_title = item_data.name
	slot_description = item_data.description
	_show_model(item_data)

func clear_slot() -> void:
	slot_data = null
	slot_filled = false
	slot_title = ""
	slot_description = ""
	_free_model()
	viewport_container.visible = false
	icon.visible = true
	icon.texture = empty_icon

# --- Modelo 3D dentro do slot ---

func _show_model(item_data: ItemData) -> void:
	_free_model()

	# Item sem cena 3D: usa o ícone 2D normal.
	if item_data.world_scene_path.is_empty():
		viewport_container.visible = false
		icon.visible = true
		icon.texture = item_data.item_icon
		return

	var scene := load(item_data.world_scene_path) as PackedScene
	var instance := scene.instantiate() as Node3D
	instance.process_mode = Node.PROCESS_MODE_DISABLED   # nenhum script roda
	for body in instance.find_children("*", "RigidBody3D", true, false):
		body.freeze = true                               # sem gravidade
	model_pivot.add_child(instance)
	_model = instance
	_fit_model(instance)

	icon.visible = false
	viewport_container.visible = true

func _free_model() -> void:
	if _model:
		_model.queue_free()
		_model = null
	model_pivot.rotation = Vector3.ZERO

## Normaliza tamanho e centro: a chave tem 10 cm, uma mesa teria 2 m.
func _fit_model(model: Node3D) -> void:
	var combined := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var box: AABB = model_pivot.global_transform.affine_inverse() \
				* mesh_instance.global_transform * mesh_instance.get_aabb()
		combined = box if first else combined.merge(box)
		first = false
	if first:
		return   # não achou nenhum mesh
	var factor := 1.0 / maxf(combined.get_longest_axis_size(), 0.0001)
	model.scale = Vector3.ONE * factor
	model.position = -combined.get_center() * factor
