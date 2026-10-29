extends Node

@onready var interact_ray: ShapeCast3D = %interactRay
@onready var player = Global.player
@onready var label: Label = %Label
@onready var inventory_controller: Node = %InventoryController/InventoryCanvasLayer/PlayerInventoryUI

var current_object: Object
var interact_component: Node

# O segundo argumento é a instância física que será animada.
signal invent_on_item_collected(item_data: ItemData, world_item: Node3D)


func _ready() -> void:
	invent_on_item_collected.connect(inventory_controller.pickup_item)

	# Impede que o shape detecte o próprio corpo do jogador.
	if is_instance_valid(player) and player is CollisionObject3D:
		interact_ray.add_exception(player)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = Global.player

		if is_instance_valid(player) and player is CollisionObject3D:
			interact_ray.add_exception(player)

		return

	# ShapeCast3D pode atingir vários corpos; pega o mais próximo.
	var potential_object: Object = _get_closest_collider()

	if current_object:
		if not is_instance_valid(current_object):
			_clear_interaction()
			return

		if potential_object != current_object:
			_unfocus()
		else:
			_focus()

		var distancia: float = player.global_position.distance_to(
			current_object.global_position
		)

		if distancia > 3.0:
			_clear_interaction()
			return

		if player.player_input.is_interacting:
			interact_component.interact()
			label.text = interact_component.interact_label
		else:
			_clear_interaction()

	else:
		if potential_object and potential_object is Node:
			interact_component = potential_object.get_node_or_null(
				"InteractionComponent"
			)

			if interact_component:
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
					interact_component.can_interact
					and player.player_input.is_interacting
				):
					current_object = potential_object
					interact_component.pre_interact()
			else:
				_unfocus()
		else:
			_unfocus()


# Retorna o collider mais próximo da origem do ShapeCast3D.
func _get_closest_collider() -> Object:
	if not interact_ray.is_colliding():
		return null

	var origin: Vector3 = interact_ray.global_position
	var closest: Object = null
	var closest_dist := INF

	for i in interact_ray.get_collision_count():
		var point: Vector3 = interact_ray.get_collision_point(i)
		var dist := origin.distance_squared_to(point)

		if dist < closest_dist:
			closest_dist = dist
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
	if label:
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

	# A animação precisa saber qual instância mover.
	# O retorno false significa que o item não foi aceito.
	if not inventory_controller.pickup_item(item_data, world_item):
		# Inventário cheio ou coleta indisponível.
		# O objeto continua no mundo para uma nova tentativa.
		ic.can_interact = true
		ic.is_collecting = false
		return

	# IMPORTANTE:
	# Não use queue_free() aqui.
	# O InventoryController remove o objeto ao terminar a animação.


func _get_world_item_node(item: Node) -> Node3D:
	# Em algumas cenas, o corpo físico fica dentro da raiz
	# da cena do item. Nesse caso, animamos a raiz inteira.
	var root := item.get_parent()

	if (
		root is Node3D
		and root.scene_file_path != ""
		and root.get_child_count() == 1
	):
		return root as Node3D

	# Se o corpo físico for a própria representação do objeto,
	# animamos o corpo recebido pelo sinal.
	return item as Node3D


# =========================================================
# ADIÇÃO AO INVENTÁRIO POR SINAL
# =========================================================

# Mantido para outros pontos do projeto que já usem este método.
# Para animar, passe também a instância do objeto no mundo.
func _add_item_to_inventory(
	item_data: ItemData,
	world_item: Node3D = null
) -> void:
	if item_data == null:
		print("ItemData não encontrado.")
		return

	invent_on_item_collected.emit(item_data, world_item)
