extends Node
class_name InventoryManagerService

# Dados persistentes entre cenas. Registre este script como Autoload
# com o nome exato "InventoryManager" nas configurações do projeto.
var items: Array[ItemData] = []


func ensure_capacity(slot_count: int) -> void:
	if slot_count < 0:
		return

	while items.size() < slot_count:
		items.append(null)

	# Não reduzimos o array automaticamente para não apagar dados
	# caso uma cena tenha menos slots que outra.


func get_item(slot_index: int) -> ItemData:
	if slot_index < 0 or slot_index >= items.size():
		return null

	return items[slot_index]


func set_item(slot_index: int, item_data: ItemData) -> void:
	if slot_index < 0:
		return

	ensure_capacity(slot_index + 1)
	items[slot_index] = item_data


func clear_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= items.size():
		return

	items[slot_index] = null


func clear_inventory() -> void:
	for i in range(items.size()):
		items[i] = null
