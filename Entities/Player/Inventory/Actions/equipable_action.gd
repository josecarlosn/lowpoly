extends ActionData
class_name EquipableAction

@export var one_time_use: bool = true
@export var name: String = "Equipable Item"
@export var success_message : String = "Success!"

func _init() -> void:
	action_type = ActionType.EQUIPABLE
