extends Node3D
class_name EquippedItemBehavior

## Uma animação pode chamar notify_action_effect no frame exato em que o efeito deve ocorrer.
signal action_effect_marker

var item_data: ItemData
var player: Player
var equipment_controller


func configure(
	_equipped_item_data: ItemData,
	_player: Player,
	_equipment_controller
) -> void:
	item_data = _equipped_item_data
	player = _player
	equipment_controller = _equipment_controller
	on_equipped()


## Pontos de extensão para scripts de itens concretos.
func on_equipped() -> void:
	pass


func on_unequipped() -> void:
	pass


## Clique esquerdo quando não existe um alvo contextual.
func use_primary() -> ItemUseResult:
	return ItemUseResult.not_handled()


## Tecla de uso secundário (F por padrão no projeto atual).
func use_secondary() -> ItemUseResult:
	return ItemUseResult.not_handled()


## Tecla de recarga (R por padrão). Cada equipamento decide se implementa.
func reload() -> ItemUseResult:
	return ItemUseResult.not_handled()


## Adicione esta função como Call Method Track na animação para sincronizar o efeito.
func notify_action_effect() -> void:
	action_effect_marker.emit()
