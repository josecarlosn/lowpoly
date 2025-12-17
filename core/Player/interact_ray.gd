extends RayCast3D

@onready var label = $Label
@onready var crosshair = $"../Control"
func _ready() -> void:
	
	var player = $"../../.."
	add_exception(player) #Faz do jogador uma exceção.

func _process(delta: float) -> void:
	label.text = ""
	crosshair.visible = true
	if is_colliding():
		var detected = get_collider()
		if detected is Interactable:
			crosshair.visible = false
			label.text = detected.label

			
