class_name IdleCrouchingPlayerState extends State
@onready var player_movement: PlayerMovement = $"../../PlayerMovement"
func update(_delta: float) -> void:
	if !Global.player._is_crouching and Global.player.velocity.length() == 0.0:
		transition.emit("IdlePlayerState")
	elif !Global.player._is_crouching and Global.player.velocity.length() > 1 and Global.player.velocity.length() < 1.8:
		transition.emit("WalkingPlayerState")
	elif Global.player._is_crouching and Global.player.velocity.length() > 0.0:
		transition.emit("CrouchingWalkingPlayerState")

func physics_update(_delta: float) -> void:
	player_movement.move(_delta)
