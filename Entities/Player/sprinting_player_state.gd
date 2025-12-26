class_name SprintingPlayerState extends State

func update(_delta: float) -> void:
	if Global.player.velocity.length() == 0.0:
		transition.emit("IdlePlayerState")
	elif Global.player.velocity.length() <= 2:
		transition.emit("WalkingPlayerState")
