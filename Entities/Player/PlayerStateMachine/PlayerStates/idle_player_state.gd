class_name IdlePlayerState extends State
@onready var player_movement: PlayerMovement = $"../../PlayerMovement"
func update(_delta: float) -> void:
	var player := Global.player
	if player._is_crouching == true and player.velocity.length() == 0.0:
		transition.emit("CrouchingIdlePlayerState")
	elif player._is_crouching == true and player.velocity.length() > 0.0:
		transition.emit("CrouchingWalkingPlayerState")
	elif player.velocity.length() > 0.0 and player.velocity.length() < 3:
		transition.emit("WalkingPlayerState")
	elif player.velocity.length() > 1:
		transition.emit("SprintingPlayerState")

func physics_update(_delta: float) -> void:
	player_movement.move(_delta)
