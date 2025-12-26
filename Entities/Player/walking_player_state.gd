class_name WalkingPlayerState extends State

func update(_delta: float) -> void:
	if Global.player.velocity.length() == 0.0:
		transition.emit("IdlePlayerState")
	elif Global.player.velocity.length() > 2:
		transition.emit("SprintingPlayerState")
	elif Global.player._is_crouching and Global.player.velocity.length() > 0.0:
		transition.emit("WalkingCrouchingPlayerState")
