extends Resource
class_name ItemData
@export_group("MetaData")
@export var id: StringName	
@export var name: String
@export var description: String
@export var item_icon: Texture #Obsoleto
@export_group("Action")
@export var action_data: ActionData
@export_group("World")
@export_file("*.tscn")
var world_scene_path: String = ""
@export_group("Equipment")
@export_file("*.tscn")
var hand_scene_path: String = ""

func _to_string() -> String:
	return id
