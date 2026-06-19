extends CanvasLayer

@onready var debug: CanvasLayer = %Debug
@onready var player = Global.player

func _process(delta: float) -> void:
	if not player:
		player = Global.player
	debug.visible = player.player_input.in_debug
