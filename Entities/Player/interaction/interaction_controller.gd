extends Node
@onready var interaction_controller: Node = %InteractionController
@onready var interact_ray: RayCast3D = %interactRay
@onready var camera_3d: PlayerCamera = $"../head/Camera3D"
@onready var player = Global.player
var current_object: Object
var last_potential_object: Object
var interact_component: Node

func _process(delta: float) -> void:
	if not player:
		player = Global.player
		return
	if current_object:
		if player.player_input.is_interacting:
			if interact_component:
				var distancia = player.global_position.distance_to(current_object.global_position)
				if distancia > 3.0:
					interact_component.postInteract()
					current_object = null
					return
				interact_component.Interact()
		else:
			if interact_component:
				interact_component.postInteract()
				current_object = null
	else:
		var potential_object: Object = interact_ray.get_collider()
		if potential_object and potential_object is Node:
			interact_component = potential_object.get_node_or_null("InteractionComponent")
			if interact_component:
				if interact_component.can_interact == false:
					return
				last_potential_object = current_object
				if player.player_input.is_interacting:
					current_object = potential_object
					interact_component.preInteract()
