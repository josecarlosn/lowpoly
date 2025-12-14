extends RayCast3D

@onready var dot = $Label

func _ready() -> void:
	
	var player = $"../../.."
	add_exception(player) #Faz do jogador uma exceção.

func _process(delta: float) -> void:
	dot.text = ""
	if is_colliding():
		var detected = get_collider()
	
		if detected.is_in_group("Interactable") == true:
			dot.text = "detected.name"
