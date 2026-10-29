class_name State extends Node

signal transition(new_state_name: StringName)

var can_interact: bool = true

func enter():
	pass
func exit():
	pass
func update(_delta: float) -> void:
	pass
func physics_update(_delta: float) -> void:
	pass
