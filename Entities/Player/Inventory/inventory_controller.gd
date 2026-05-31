extends Node

@onready var player = Global.player
@onready var inventory_canvas_layer: CanvasLayer = $InventoryCanvasLayer
@onready var player_input: PlayerInput = $"../PlayerInput"

func _process(delta: float) -> void:
	handle_inventory_visibility()
		
func handle_inventory_visibility():
	inventory_canvas_layer.visible = player_input.in_inventory
