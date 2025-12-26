class_name StateMachine extends Node

@onready var debug_label: Label = $"../Debug/Panel/Label"

@export var CURRENT_STATE: State
var states: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.transition.connect(on_child_transition)
		else:
			push_warning("****Child whith a incompatible state****")
	CURRENT_STATE.enter()
	
func _process(delta: float) -> void:
	debug_label.text ="Player velocity: " + str(Global.player.velocity.length()) +"\nCurrent State: " + CURRENT_STATE.name +"\nFPS: " + str(Engine.get_frames_per_second())


	CURRENT_STATE.update(delta)
func _physics_process(delta: float) -> void:
	CURRENT_STATE.physics_update(delta)

func on_child_transition(new_state_name: StringName) -> void:
	var new_state = states.get(new_state_name)
	if new_state != null:
		CURRENT_STATE.exit()
		new_state.enter()
		CURRENT_STATE = new_state
	else:
		push_warning("State does'nt exist")
