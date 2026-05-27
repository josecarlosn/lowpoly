class_name PlayerMovement extends Node

func move() -> void:
	var player := Global.player
	player.player_input.poll(player.head.transform.basis)
	var direction := player.player_input.direction
	if direction:
		player.velocity.x = direction.x * player.SPEED
		player.velocity.z = direction.z * player.SPEED
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)
		player.velocity.z = move_toward(player.velocity.z, 0, player.SPEED)
	player.move_and_slide()
