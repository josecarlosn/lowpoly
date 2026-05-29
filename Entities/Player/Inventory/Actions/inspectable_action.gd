extends ActionData
class_name InspectableAction

@export var name: String = "Inspectable item"

func _init() -> void:
	action_type = ActionType.INSPECTABLE
