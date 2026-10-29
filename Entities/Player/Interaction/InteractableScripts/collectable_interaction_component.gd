extends Node
class_name CollectableInteraction

@export_category("Settings")
@export var collectable_ref: Node3D
@export var item_data: ItemData
@export var can_collect: bool = true

@export_category("Label Settings")
var interact_label: String
@export var hover_label: String

var can_interact: bool = true
var is_interacting: bool = false
var is_collecting: bool = false
var collect_speed: float = 7.5
#---SIGNALS---

signal item_collected(item_data: Node)

func _ready() -> void:
	pass
	
func _physics_process(delta: float) -> void:
	pass
	#if not is_collecting:
		#return
#
	#var target := Global.player.inventory_target.global_position
#
	## Mantém a altura atual do item
	#target.y = collectable_ref.global_position.y 
	#collectable_ref.global_position = collectable_ref.global_position.move_toward(
		#target,
		#collect_speed * delta
	#)
#
	## VERIFICAÇÃO: O item chegou ao destino?
	#if collectable_ref.global_position.is_equal_approx(target):
		## 1. (Opcional) Diga ao inventário para somar o item aqui, se já não tiver feito antes.
		## Global.player.add_to_inventory(item_dados)
		#
		## 2. Deleta o item do jogo
		#collectable_ref.queue_free()
func pre_interact() -> void:
	is_interacting = true
func interact() -> void:
	if not can_interact:
		return

	_try_interact()
	
func post_interact() -> void:
	is_interacting = false
	# Soltou o botão e o item não foi coletado (inventário cheio): libera nova tentativa
	if is_collecting == false:
		can_interact = true
		

func _try_interact() -> void:
	if can_collect:
		# marca ANTES de emitir, para o controller poder desfazer se a coleta falhar
		can_interact = false
		is_collecting = true
		item_collected.emit(collectable_ref)
	else:
		print("Cannot collect")
