
extends Node
class_name DefaultInteraction

@export_category("Settings")
@export var can_interact: bool = true

@export_category("Label Settings")
@export var hover_label: String
@export var click_label: String

var interact_label: String = ""


func pre_interact() -> void:
	pass


func interact() -> void:
	interact_label = click_label


func post_interact() -> void:
	pass
