extends Node

#@onready var interaction_controller: Node = %InteractionController
#@onready var camera_3d: PlayerCamera = $"../head/Camera3D"
@onready var interact_ray: RayCast3D = %interactRay
@onready var player = Global.player
@onready var label: Label = %Label

var current_object: Object
var interact_component: Node

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
