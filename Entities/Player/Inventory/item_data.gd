extends Resource
class_name ItemData
@export_group("MetaData")
@export var id: StringName	
@export var name: String
@export var description: String
@export var item_icon: Texture #Obsoleto
@export_group("Action")
@export var action_data: ActionData

## Estado por instância do item (munição, estado da lanterna, durabilidade etc.).
## O inventário cria uma cópia deste recurso para cada item coletado.
@export_storage var runtime_state: Dictionary = {}
@export_group("World")
@export_file("*.tscn")
var world_scene_path: String = ""
@export_group("Equipment")
@export_file("*.tscn")
var hand_scene_path: String = ""

## Cria uma cópia independente para esta unidade do item no inventário.
## O recurso original que está na cena/.tres permanece como definição.
func create_runtime_copy() -> ItemData:
	var runtime_copy := duplicate(true) as ItemData
	runtime_copy.runtime_state = runtime_state.duplicate(true)
	return runtime_copy


func _to_string() -> String:
	return str(id)
