extends RayCast3D

@onready var label = $Label
@onready var crosshair = $Crosshair
@onready var note_control: Control = %NoteControl
@onready var note_texture: TextureRect = %NoteTexture
@onready var note_label: RichTextLabel = %NoteLabel
@onready var player: CharacterBody3D = $"../../.."


func _ready() -> void:
	note_control.visible = false
	add_exception(player) #Faz do jogador uma exceção.

func _process(delta: float) -> void:
	label.text = ""
	crosshair.visible = true
	if is_colliding():
		var detected = get_collider()
		if detected is Interactable:
			crosshair.visible = false
			label.text = detected.label
			if Input.is_action_just_pressed("use"):
				player.can_move = false
				if note_control.visible == false:
					note_control.visible = true
					note_label.text = detected.content
				else: 
					player.can_move = true
					note_control.visible = false	
		#
		#var detected = get_collider()
		#if detected is Interactable:
			##crosshair.visible = false
			#label.text = detected.label

			
