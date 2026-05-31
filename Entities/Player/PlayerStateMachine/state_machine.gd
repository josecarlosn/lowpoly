class_name StateMachine extends Node

@onready var debug_label: Label = %Title


@export var CURRENT_STATE: State
@export var PREVIOUS_STATE: State
var states: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.transition.connect(on_child_transition)
		else:
			push_warning("****Child whith a incompatible state****")
	if CURRENT_STATE:
		CURRENT_STATE.enter()
	else:
		push_warning("Initial state not set")

	
func _process(delta: float) -> void:
	debug_label.text ="Player velocity: " + str(Global.player.velocity.length()) +"\nCurrent State: " + CURRENT_STATE.name + "\nPrevious State: " + PREVIOUS_STATE.name +"\nFPS: " + str(Engine.get_frames_per_second()) + "\nCan move: " + str(Global.player.can_move)


	CURRENT_STATE.update(delta)
func _physics_process(delta: float) -> void:
	CURRENT_STATE.physics_update(delta)

func on_child_transition(new_state_name: String) -> void:
	var new_state = states.get(new_state_name)
	if new_state != null:
		PREVIOUS_STATE = CURRENT_STATE
		CURRENT_STATE.exit()
		new_state.enter()
		CURRENT_STATE = new_state
	else:
		push_warning("State does'nt exist")
