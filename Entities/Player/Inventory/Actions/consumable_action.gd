extends ActionData
class_name ConsumableAction

## Valor configurável para o efeito do consumível (por exemplo, quantidade de cura).
@export var modifier_value: int = 0


func _init() -> void:
	action_type = ActionType.CONSUMABLE


func get_success_disposition() -> ActionData.ItemDisposition:
	return ActionData.ItemDisposition.CONSUME
