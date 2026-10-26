extends Resource
class_name ItemData

@export var id: StringName	
@export var name: String
@export var description: String
@export var item_icon: Texture #Obsoleto
@export var action_data: ActionData
@export_file("*.tscn") var world_scene_path: String

func _to_string() -> String:
	return id
