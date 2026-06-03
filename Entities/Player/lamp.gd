extends SpotLight3D

@onready var player = Global.player

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if not player:
		player = Global.player
	if player.player_input.lamp_request:
		visible = not visible
		
