extends Node
class_name ItemActionController

const TRANSFER_DEFAULT_DURATION := 0.35
const TRANSFER_DEFAULT_ARC_HEIGHT := 0.15

@onready var player: Player = get_parent() as Player
@onready var equipment: EquipmentController = get_node_or_null("../EquipmentController") as EquipmentController
@onready var inventory: InventoryController = get_node_or_null(
	"../InventoryController/InventoryCanvasLayer/PlayerInventoryUI"
) as InventoryController

var action_in_progress: bool = false
var suppress_primary_until_release: bool = false

var _pending_result: ItemUseResult
var _pending_effect_called: bool = false
var _pending_effect_succeeded: bool = false


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_released("primary"):
		suppress_primary_until_release = false

	if action_in_progress or not is_instance_valid(player):
		return

	if player.player_input.in_inventory:
		return

	if Input.is_action_just_pressed("secondary_use"):
		await use_secondary()
	elif Input.is_action_just_pressed("reload"):
		await reload_equipped_item()


## O alvo decide se aceita o item. Retorna NOT_HANDLED se não implementar essa interação.
func try_use_on_target(target: Node) -> ItemUseResult:
	if action_in_progress or not is_instance_valid(target):
		return ItemUseResult.not_handled()

	if equipment == null or equipment.current_item == null:
		return ItemUseResult.not_handled()

	if equipment.is_transitioning or equipment.action_locked:
		suppress_primary_until_release = true
		return ItemUseResult.failed("Aguarde a animação do equipamento terminar.")

	if not is_instance_valid(equipment.equipped_instance):
		return ItemUseResult.not_handled()

	if not target.has_method("try_use_item"):
		return ItemUseResult.not_handled()

	var item_data: ItemData = equipment.current_item
	var returned_value: Variant = target.call(
		"try_use_item",
		item_data,
		player,
		equipment.equipped_instance
	)

	if not (returned_value is ItemUseResult):
		push_warning(
			"try_use_item() deve retornar um ItemUseResult: "
			+ str(target.get_path())
		)
		return ItemUseResult.not_handled()

	var result: ItemUseResult = returned_value
	if result.status == ItemUseResult.Status.NOT_HANDLED:
		return result

	suppress_primary_until_release = true
	await _execute_result(result, item_data)
	return result


func use_primary() -> ItemUseResult:
	return await _use_equipped_action("primary")


func use_secondary() -> ItemUseResult:
	return await _use_equipped_action("secondary")


func reload_equipped_item() -> ItemUseResult:
	return await _use_equipped_action("reload")


func _use_equipped_action(action_name: String) -> ItemUseResult:
	if action_in_progress or equipment == null:
		return ItemUseResult.not_handled()

	if equipment.is_transitioning or equipment.action_locked:
		return ItemUseResult.not_handled()

	var item_data: ItemData = equipment.current_item
	var behavior := equipment.get_current_behavior()

	if item_data == null or behavior == null:
		return ItemUseResult.not_handled()

	var result: ItemUseResult
	match action_name:
		"secondary":
			result = behavior.use_secondary()
		"reload":
			result = behavior.reload()
		_:
			result = behavior.use_primary()

	if result == null or result.status == ItemUseResult.Status.NOT_HANDLED:
		return ItemUseResult.not_handled()

	if action_name == "primary":
		suppress_primary_until_release = true

	await _execute_result(result, item_data)
	return result


func _execute_result(result: ItemUseResult, item_data: ItemData) -> void:
	if result.status != ItemUseResult.Status.SUCCESS:
		return

	if equipment == null or inventory == null:
		result.status = ItemUseResult.Status.FAILED
		result.message = "O sistema de equipamento ou inventário não foi encontrado."
		return

	action_in_progress = true
	equipment.action_locked = true

	var disposition := _resolve_disposition(result, item_data)
	var succeeded := false

	if disposition == ItemUseResult.Disposition.TRANSFER:
		succeeded = await _transfer_equipped_item(result, item_data)
	else:
		succeeded = await _play_animation_and_apply_effect(result, item_data)

	if succeeded:
		match disposition:
			ItemUseResult.Disposition.CONSUME:
				var removed: bool = await inventory.consume_item(item_data)
				if not removed:
					push_warning("A ação terminou, mas o item não foi encontrado no inventário.")
			ItemUseResult.Disposition.KEEP:
				pass
			ItemUseResult.Disposition.TRANSFER:
				pass
	else:
		result.status = ItemUseResult.Status.FAILED
		if result.message.is_empty():
			result.message = "Não foi possível concluir a ação."

	equipment.action_locked = false
	action_in_progress = false


func _resolve_disposition(
	result: ItemUseResult,
	item_data: ItemData
) -> ItemUseResult.Disposition:
	if result.disposition != ItemUseResult.Disposition.DEFAULT:
		return result.disposition

	if item_data.action_data == null:
		return ItemUseResult.Disposition.KEEP

	match item_data.action_data.get_success_disposition():
		ActionData.ItemDisposition.CONSUME:
			return ItemUseResult.Disposition.CONSUME
		ActionData.ItemDisposition.TRANSFER:
			return ItemUseResult.Disposition.TRANSFER
		_:
			return ItemUseResult.Disposition.KEEP


func _play_animation_and_apply_effect(
	result: ItemUseResult,
	item_data: ItemData
) -> bool:
	var item_instance := equipment.equipped_instance
	if not is_instance_valid(item_instance):
		return false

	var action_data: ActionData = item_data.action_data
	var animation_name := result.animation_name
	if animation_name.is_empty() and action_data != null:
		animation_name = action_data.animation_name

	var animation_player := _find_animation_player(item_instance, action_data)
	if (
		animation_name.is_empty()
		or animation_player == null
		or not animation_player.has_animation(animation_name)
	):
		return _apply_effect(result)

	_pending_result = result
	_pending_effect_called = false
	_pending_effect_succeeded = false

	var behavior := equipment.get_current_behavior()
	var marker_callable := Callable(self, "_on_action_effect_marker")
	var marker_connected := false

	if is_instance_valid(behavior):
		if not behavior.action_effect_marker.is_connected(marker_callable):
			behavior.action_effect_marker.connect(marker_callable)
			marker_connected = true

	animation_player.play(animation_name)
	await animation_player.animation_finished

	# Sem um marcador na animação, aplica o efeito ao final dela.
	if not _pending_effect_called:
		_commit_pending_effect()

	if (
		marker_connected
		and is_instance_valid(behavior)
		and behavior.action_effect_marker.is_connected(marker_callable)
	):
		behavior.action_effect_marker.disconnect(marker_callable)

	var succeeded := _pending_effect_succeeded
	_pending_result = null
	return succeeded


func _find_animation_player(
	item_instance: Node3D,
	action_data: ActionData
) -> AnimationPlayer:
	if action_data != null and not action_data.animation_player_path.is_empty():
		var configured_player := item_instance.get_node_or_null(
			action_data.animation_player_path
		) as AnimationPlayer
		if configured_player != null:
			return configured_player

	return item_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _on_action_effect_marker() -> void:
	_commit_pending_effect()


func _commit_pending_effect() -> void:
	if _pending_result == null or _pending_effect_called:
		return

	_pending_effect_called = true
	_pending_effect_succeeded = _apply_effect(_pending_result)


func _apply_effect(result: ItemUseResult) -> bool:
	if not result.effect.is_valid():
		return true

	var returned_value: Variant = result.effect.call()
	if typeof(returned_value) == TYPE_BOOL:
		return returned_value

	return true


func _transfer_equipped_item(
	result: ItemUseResult,
	item_data: ItemData
) -> bool:
	var target := result.transfer_target
	var item_instance := equipment.equipped_instance
	var scene_root := get_tree().current_scene

	if (
		not is_instance_valid(target)
		or not is_instance_valid(item_instance)
		or equipment.current_item != item_data
		or scene_root == null
	):
		return false

	var old_parent := item_instance.get_parent()
	var old_transform := item_instance.transform
	var start_position := item_instance.global_position
	var action_data: ActionData = item_data.action_data
	var duration := TRANSFER_DEFAULT_DURATION
	var arc_height := TRANSFER_DEFAULT_ARC_HEIGHT

	if action_data != null:
		duration = action_data.transfer_duration
		arc_height = action_data.transfer_arc_height

	# A instância deixa a mão e passa a existir no mundo durante o trajeto.
	item_instance.reparent(scene_root, true)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		_update_item_transfer.bind(
			item_instance,
			target,
			start_position,
			arc_height
		),
		0.0,
		1.0,
		duration
	)
	await tween.finished

	if not is_instance_valid(item_instance) or not is_instance_valid(target):
		_restore_transferred_item(item_instance, old_parent, old_transform)
		return false

	# Alinha o modelo ao ponto de encaixe do objeto receptor.
	item_instance.reparent(target, true)
	item_instance.global_transform = target.global_transform

	if not _apply_effect(result):
		_restore_transferred_item(item_instance, old_parent, old_transform)
		return false

	equipment.release_equipped_instance_for_transfer()
	inventory.remove_item_reference(item_data)
	return true


func _update_item_transfer(
	progress: float,
	item_instance: Node3D,
	target: Node3D,
	start_position: Vector3,
	arc_height: float
) -> void:
	if not is_instance_valid(item_instance) or not is_instance_valid(target):
		return

	var end_position := target.global_position
	var position := start_position.lerp(end_position, progress)
	position.y += sin(progress * PI) * arc_height
	item_instance.global_position = position


func _restore_transferred_item(
	item_instance: Node3D,
	old_parent: Node,
	old_transform: Transform3D
) -> void:
	if not is_instance_valid(item_instance) or not is_instance_valid(old_parent):
		return

	item_instance.reparent(old_parent, false)
	item_instance.transform = old_transform
