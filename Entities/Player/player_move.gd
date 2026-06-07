class_name PlayerMovement extends Node

@export_category("Movement Delays")
@export var move_delay := 0.15
@export var stop_delay := 0.35

@export_category("Acceleration")
@export var accel_rate := 7.5
@export var decel_rate := 7.5

var _speed_factor   := 0.0
var _move_timer     := 0.0
var _stop_timer     := 0.0
var _has_input      := false
var _last_direction := Vector3.ZERO
var _prev_has_input := false  # ← novo: rastreia o frame anterior

func move(delta: float) -> void:
	var player := Global.player
	player.player_input.poll(player.head.transform.basis)
	var direction := player.player_input.direction
	if player.can_move:
		if direction:	
			_has_input      = true
			_last_direction = direction
			_stop_timer     = 0.0
		else:
			_has_input  = false
			_stop_timer += delta

		# ── detecta borda de subida do input ─────────────────────
		if _has_input and not _prev_has_input:
			_move_timer = 0.0  # ← reseta SEMPRE que o botão é pressionado
		_prev_has_input = _has_input

		# ── atualiza move_timer só enquanto tem input ─────────────
		if _has_input:
			_move_timer += delta

		# ── atualiza speed_factor ─────────────────────────────────
		if _has_input and _move_timer >= move_delay:
			_speed_factor = lerp(_speed_factor, 1.0, 1.0 - exp(-accel_rate * delta))
		elif _has_input and _move_timer < move_delay:
			pass  # mantém a velocidade atual durante o delay
		elif not _has_input and _stop_timer >= stop_delay:
			_speed_factor = lerp(_speed_factor, 0.0, 1.0 - exp(-decel_rate * delta))

		if _speed_factor < 0.005:
			_speed_factor = 0.0

		var target := _last_direction * player.SPEED * _speed_factor
		player.velocity.x = target.x
		player.velocity.z = target.z
		player.handle_push()
		player.move_and_slide()
