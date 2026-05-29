extends ActionData
class_name ConsumableAction	
@export var modifier_name: String = "Bandagem"
@export var modifier_value: int = 30

func _init() -> void:
	action_type = ActionType.CONSUMABLE
