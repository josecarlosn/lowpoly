class_name IdleCrouchingPlayerState extends State

func update(_delta: float) -> void:
	if !Global.player._is_crouching and Global.player.velocity.length() == 0.0:
		transition.emit("IdlePlayerState")
	elif !Global.player._is_crouching and Global.player.velocity.length() > 1 and Global.player.velocity.length() < 1.8:
		transition.emit("WalkingPlayerState")
	elif !Global.player._is_crouching and Global.player.velocity.length() > 3:
		transition.emit("SprintingPlayerState")
	elif Global.player._is_crouching and Global.player.velocity.length() > 0.0:
		transition.emit("WalkingCrouchingPlayerState")
