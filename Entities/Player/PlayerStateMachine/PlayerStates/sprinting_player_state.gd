class_name SprintingPlayerState extends State
@onready var player_movement: PlayerMovement = $"../../PlayerMovement"
func update(_delta: float) -> void:
	var player := Global.player
	if player._is_crouching == true and player.velocity.length() == 0.0:
		transition.emit("CrouchingIdlePlayerState")
	elif player._is_crouching == true and player.velocity.length() > 0.0:
		transition.emit("CrouchingWalkingPlayerState")
	elif player._is_sprinting == false and player.velocity.length() == 0.0:
		transition.emit("IdlePlayerState")
	elif player._is_sprinting == false and player.velocity.length() > 0.0:
		transition.emit("WalkingPlayerState")

func physics_update(_delta: float) -> void:
	player_movement.move()
	
