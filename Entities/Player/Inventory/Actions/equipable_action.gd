extends ActionData
class_name EquipableAction

## Compatibilidade com o campo antigo. Ferramentas são reutilizáveis por padrão.
@export var one_time_use: bool = false
@export var success_message: String = "Success!"


func _init() -> void:
	action_type = ActionType.EQUIPABLE


func get_success_disposition() -> ActionData.ItemDisposition:
	return ActionData.ItemDisposition.CONSUME if one_time_use else ActionData.ItemDisposition.KEEP
