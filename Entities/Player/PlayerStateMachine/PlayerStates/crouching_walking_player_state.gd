class_name WalkingCrouchingPlayerState extends State
@onready var player_movement: PlayerMovement = $"../../PlayerMovement"
func update(_delta: float) -> void:
	if Global.player._is_crouching and Global.player.velocity.length() == 0:
		transition.emit("CrouchingIdlePlayerState")
	elif !Global.player._is_crouching and Global.player.velocity.length() == 0:
		transition.emit("IdlePlayerState")
	elif !Global.player._is_crouching and Global.player.velocity.length() > 0:
		transition.emit("IdlePlayerState")

func physics_update(_delta: float) -> void:
	player_movement.move()
