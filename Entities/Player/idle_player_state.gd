class_name IdlePlayerState extends State

func update(_delta: float) -> void:
	if Global.player._is_crouching == true and Global.player.velocity.length() == 0.0:
		transition.emit("IdleCrouchingPlayerState")
	elif Global.player._is_crouching == true and Global.player.velocity.length() > 0.0:
		transition.emit("WalkingCrouchingPlayerState")
	else:
		if Global.player.velocity.length() > 0.0 and Global.player.velocity.length() < 3:
			transition.emit("WalkingPlayerState")
		elif Global.player.velocity.length() > 1:
			transition.emit("SprintingPlayerState")
		
