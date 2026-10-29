extends EquippedItemBehavior
class_name LampEquippedBehavior


func on_equipped() -> void:
	_set_light_visible(bool(item_data.runtime_state.get("is_on", false)))


func on_unequipped() -> void:
	# A luz pertence ao equipamento: ela não deve continuar ativa sem a lanterna na mão.
	item_data.runtime_state["is_on"] = false
	_set_light_visible(false)


func use_primary() -> ItemUseResult:
	return ItemUseResult.completed(Callable(self, "_toggle_player_light"))


func use_secondary() -> ItemUseResult:
	return ItemUseResult.completed(Callable(self, "_toggle_player_light"))


func _toggle_player_light() -> bool:
	if not is_instance_valid(player):
		return false

	var light := player.get_node_or_null("head/Camera3D/SpotLight3D") as SpotLight3D
	if light == null:
		return false

	var next_state := not light.visible
	_set_light_visible(next_state)
	item_data.runtime_state["is_on"] = next_state
	return true


func _set_light_visible(value: bool) -> void:
	if not is_instance_valid(player):
		return

	var light := player.get_node_or_null("head/Camera3D/SpotLight3D") as SpotLight3D
	if light != null:
		light.visible = value
