extends Node
@onready var interaction_controller: Node = %InteractionController
@onready var interact_ray: RayCast3D = %interactRay
@onready var camera_3d: PlayerCamera = $"../head/Camera3D"
@onready var player = Global.player
@onready var label: Label = %Label
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
					label.text = interact_component.label
					interact_component.postInteract()
					current_object = null
					
					return
				if interact_component.is_locked:
					label.text = interact_component.label_if_door_is_locked
					interact_component.sound_if_door_is_locked.play()
				else:
					label.text = interact_component.label
				interact_component.Interact()
				#if not interact_component.description:
					#label.text = interact_component.label
#
				#else:
					#label.visible = true
					#label.text = interact_component.editor_description
				
					
		else:
			if interact_component:
				label.text = interact_component.label
				interact_component.postInteract()
				current_object = null
	else:
		var potential_object: Object = interact_ray.get_collider()
		if potential_object and potential_object is Node:
			interact_component = potential_object.get_node_or_null("InteractionComponent")
			if interact_component:
				if not interact_component.can_interact:
					return
				_focus()
				last_potential_object = current_object
				if player.player_input.is_interacting:
					current_object = potential_object
					interact_component.preInteract()
			else:
				_unfocus()
		else:
			_unfocus()

func locked_label_timer():
	label.text = interact_component.label_if_door_is_locked
	get_tree().create_timer(0.5)
func _focus() -> void:
	label.visible = true
func _unfocus() -> void:
	label.visible = false
