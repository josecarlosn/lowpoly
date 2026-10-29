extends Node

@onready var interact_ray: ShapeCast3D = %interactRay
@onready var player: Player = get_parent() as Player
@onready var label: Label = %Label
@onready var inventory_controller: InventoryController = get_node(
	"../InventoryController/InventoryCanvasLayer/PlayerInventoryUI"
) as InventoryController

var current_object: Object
var interact_component


signal invent_on_item_collected(item_data: ItemData, world_item: Node3D)


func _ready() -> void:
	invent_on_item_collected.connect(inventory_controller.pickup_item)

	# Impede que o ShapeCast detecte o próprio jogador.
	if is_instance_valid(player) and player is CollisionObject3D:
		interact_ray.add_exception(player)

	_unfocus()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = Global.player

		if is_instance_valid(player) and player is CollisionObject3D:
			interact_ray.add_exception(player)

		_unfocus()
		return

	var action_controller := _get_item_action_controller()

	# Não mantém a label de interação visível durante outra ação.
	if action_controller != null and action_controller.action_in_progress:
		_unfocus()
		return

	var potential_object: Object = _get_closest_collider()

	# Se o alvo mudou ou deixou de existir, encerra a interação anterior.
	if current_object != null:
		if (
			not is_instance_valid(current_object)
			or potential_object != current_object
		):
			_clear_interaction()

	# Interação iniciada e botão ainda pressionado.
	if current_object != null:
		var current_node := current_object as Node3D

		if (
			current_node == null
			or not is_instance_valid(interact_component)
		):
			_clear_interaction()
			return

		if not interact_component.can_interact:
			_clear_interaction()
			return

		if player.global_position.distance_to(current_node.global_position) > 3.0:
			_clear_interaction()
			return

		_focus()

		if player.player_input.is_interacting:
			# Evita executar a interação normal enquanto uma ação contextual
			# já consumiu o botão principal.
			if (
				action_controller != null
				and action_controller.suppress_primary_until_release
			):
				if not interact_component.interact_label.is_empty():
					label.text = interact_component.interact_label
			else:
				interact_component.interact()
				label.text = interact_component.interact_label
		else:
			_clear_interaction()

		return

	# Apenas hover: ainda não há uma interação em andamento.
	if potential_object is Node:
		var candidate := (potential_object as Node).get_node_or_null(
			"InteractionComponent"
		)

		# Só aceita componentes válidos e que permitem interação.
		if is_instance_valid(candidate) and candidate.can_interact:
			interact_component = candidate

			# Conecta o sinal de coleta uma única vez.
			if (
				interact_component is CollectableInteraction
				and not interact_component.is_connected(
					"item_collected",
					Callable(self, "_on_item_collected")
				)
			):
				interact_component.connect(
					"item_collected",
					Callable(self, "_on_item_collected")
				)

			_focus()

			if (
				Input.is_action_just_pressed("primary")
				and not player.player_input.in_inventory
			):
				current_object = potential_object
				interact_component.pre_interact()

				# O alvo decide se aceita o item equipado.
				if (
					action_controller != null
					and action_controller_has_equipped_item()
				):
					var result: ItemUseResult = await action_controller.try_use_on_target(
						interact_component
					)

					if result.status != ItemUseResult.Status.NOT_HANDLED:
						if not result.message.is_empty():
							interact_component.interact_label = result.message
							label.text = result.message

						return

				# Compatibilidade com coleta e interações tradicionais.
				if (
					is_instance_valid(interact_component)
					and interact_component.can_interact
				):
					interact_component.interact()
					label.text = interact_component.interact_label
		else:
			# Parede, objeto sem componente ou alvo indisponível.
			_clear_interaction()

			if (
				Input.is_action_just_pressed("primary")
				and not player.player_input.in_inventory
			):
				_interact_without_target(action_controller)
	else:
		# Nenhum collider válido na mira.
		_clear_interaction()

		if (
			Input.is_action_just_pressed("primary")
			and not player.player_input.in_inventory
		):
			_interact_without_target(action_controller)


func _interact_without_target(
	action_controller: ItemActionController
) -> void:
	if action_controller == null:
		return

	await action_controller.use_primary()


func action_controller_has_equipped_item() -> bool:
	var equipment := player.get_node_or_null(
		"EquipmentController"
	) as EquipmentController

	return equipment != null and equipment.current_item != null


func _get_item_action_controller() -> ItemActionController:
	if not is_instance_valid(player):
		return null

	return player.get_node_or_null(
		"ItemActionController"
	) as ItemActionController


# Retorna o collider mais próximo da origem do ShapeCast3D.
func _get_closest_collider() -> Object:
	if not interact_ray.is_colliding():
		return null

	var origin: Vector3 = interact_ray.global_position
	var closest: Object = null
	var closest_dist: float = INF

	for i in range(interact_ray.get_collision_count()):
		var point: Vector3 = interact_ray.get_collision_point(i)
		var distance: float = origin.distance_squared_to(point)

		if distance < closest_dist:
			closest_dist = distance
			closest = interact_ray.get_collider(i)

	return closest


func _clear_interaction() -> void:
	if is_instance_valid(interact_component):
		interact_component.post_interact()

	current_object = null
	interact_component = null

	_unfocus()


func _focus() -> void:
	if label and is_instance_valid(interact_component):
		label.text = interact_component.hover_label
		label.visible = true


func _unfocus() -> void:
	if is_instance_valid(label):
		label.text = ""
		label.visible = false


# =========================================================
# COLETA DE ITENS
# =========================================================

func _on_item_collected(item: Node) -> void:
	if not is_instance_valid(item):
		return

	# O item recebido pelo sinal contém o InteractionComponent.
	var ic := item.get_node_or_null(
		"InteractionComponent"
	) as CollectableInteraction

	if ic == null or ic.item_data == null:
		return

	var item_data: ItemData = ic.item_data

	# Descobre qual nó representa o objeto inteiro no mundo.
	var world_item := _get_world_item_node(item)

	if world_item == null:
		push_warning(
			"Não foi possível encontrar o objeto Node3D para animar a coleta."
		)
		ic.can_interact = true
		ic.is_collecting = false
		return

	# O InventoryController controla a animação e a remoção do objeto.
	if not inventory_controller.pickup_item(item_data, world_item):
		# Inventário cheio ou coleta indisponível.
		ic.can_interact = true
		ic.is_collecting = false
		return

	# Não chamar queue_free() aqui.
	# O InventoryController remove o objeto após a animação.


func _get_world_item_node(item: Node) -> Node3D:
	var root := item.get_parent()

	# Em algumas cenas, o corpo físico fica dentro da raiz da cena.
	if (
		root is Node3D
		and root.scene_file_path != ""
		and root.get_child_count() == 1
	):
		return root as Node3D

	return item as Node3D

# =========================================================
# ADIÇÃO AO INVENTÁRIO POR SINAL
# =========================================================

func _add_item_to_inventory(
	item_data: ItemData,
	world_item: Node3D = null
) -> void:
	if item_data == null:
		print("ItemData não encontrado.")
		return

	invent_on_item_collected.emit(item_data, world_item)
