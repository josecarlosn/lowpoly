extends Resource
class_name ActionData

## Tipo legado mantido para compatibilidade com os recursos existentes.
enum ActionType {
	INVALID,
	CONSUMABLE,
	EQUIPABLE,
	INSPECTABLE
}

## Resultado padrão após uma ação bem-sucedida.
enum ItemDisposition {
	KEEP,
	CONSUME,
	TRANSFER
}

var action_type: ActionType = ActionType.INVALID

@export_group("Animação da ação")
## Nome da animação no AnimationPlayer do item equipado. Pode ficar vazio.
@export var animation_name: StringName = &""
## Caminho opcional relativo à raiz da cena equipada. Vazio = procurar um AnimationPlayer.
@export var animation_player_path: NodePath = NodePath()

@export_group("Transferência")
## Usado quando uma ação instala/entrega o modelo equipado a um objeto do mundo.
@export_range(0.01, 5.0, 0.01) var transfer_duration: float = 0.35
@export_range(0.0, 2.0, 0.01) var transfer_arc_height: float = 0.15


func get_success_disposition() -> ItemDisposition:
	return ItemDisposition.KEEP
