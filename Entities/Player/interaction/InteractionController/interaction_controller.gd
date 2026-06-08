extends Node

#@onready var interaction_controller: Node = %InteractionController
#@onready var camera_3d: PlayerCamera = $"../head/Camera3D"
@onready var interact_ray: RayCast3D = %interactRay
@onready var player = Global.player
@onready var label: Label = %Label
@onready var inventory_controller: Node = %InventoryController/InventoryCanvasLayer/PlayerInventoryUI

var current_object: Object
var interact_component: Node

signal invent_on_item_collected(item_data: ItemData) # Adicione o item no inventario
func _ready() -> void:
	invent_on_item_collected.connect(inventory_controller.pickup_item)
	
func _physics_process(delta: float) -> void:

	if not player:
		player = Global.player
		return

	var potential_object: Object = interact_ray.get_collider()
	if current_object:
		if not is_instance_valid(current_object):
			_clear_interaction()
			return
		if interact_ray.get_collider() != current_object:
			_unfocus()
		else:
			_focus()
		var distancia = player.global_position.distance_to(current_object.global_position)
		if distancia > 3.0:
			_clear_interaction()
			return

		if player.player_input.is_interacting:
			interact_component.interact()
			label.text = interact_component.interact_label
			#Se existir alguma label ao interagir com um objeto, ela será manipulada no componente
		else:
			_clear_interaction()
	else:
		if potential_object and potential_object is Node:
			interact_component = potential_object.get_node_or_null("InteractionComponent")
			if interact_component:
				if not interact_component.is_connected("item_collected", Callable(self, "_on_item_collected")):
					interact_component.connect("item_collected", Callable(self, "_on_item_collected"))
				_focus()
				if interact_component.can_interact and player.player_input.is_interacting:
					current_object = potential_object
					interact_component.pre_interact()
			else:
				_unfocus()
		else:
			_unfocus()

func _clear_interaction() -> void:
	if interact_component:
		interact_component.post_interact()
	current_object = null
	interact_component = null
	_unfocus()
func _focus() -> void:
	if label:
		label.text = interact_component.hover_label
		label.visible = true
func _unfocus() -> void:
	if label:
		label.visible = false
func _on_item_collected(item: Node) -> void:
	var ic = item.get_node_or_null("InteractionComponent")
	print("Aqui: ",ic)
	
	_add_item_to_inventory(ic.item_data)
	
	#await som_de_coleta.finished
	item.queue_free()
func _add_item_to_inventory(item_data: ItemData) -> void:
	if item_data != null:
		print("Coletei o ", item_data)
		invent_on_item_collected.emit(item_data)
		return
	print("Itemdata não encontrado")
	
