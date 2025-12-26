class_name IdlePlayerState extends State

func update(_delta: float) -> void:
	if Global.player.velocity.length() != 0.0:
		transition.emit("WalkingPlayerState")
		
