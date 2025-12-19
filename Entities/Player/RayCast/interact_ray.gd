extends RayCast3D

@onready var label = $Label
@onready var crosshair = $Crosshair
@onready var note_control: Control = %NoteControl
@onready var note_texture: TextureRect = %NoteTexture
@onready var note_label: RichTextLabel = %NoteLabel
@onready var player: CharacterBody3D = $"../../.."
@onready var cross_hair_action_label: Label = $Label/CrossHairActionLabel


func _ready() -> void:
	note_control.visible = false
	add_exception(player) #Faz do jogador uma exceção.

func _process(delta: float) -> void:
	cross_hair_action_label.text = ""
	label.text = ""
	crosshair.visible = true
	if is_colliding():
		var detected = get_collider()
		if detected is Interactable:
			crosshair.visible = false
			label.text = detected.label
			cross_hair_action_label.text = detected.action
			if Input.is_action_just_pressed("use"):
				player.can_move = false
				label.visible = false
				if note_control.visible == false:
					note_texture.texture = load(detected.texture_content)
					note_control.visible = true
					note_label.text = detected.content
				else: 
					label.visible = true
					player.can_move = true
					note_control.visible = false	
		#
		#var detected = get_collider()
		#if detected is Interactable:
			##crosshair.visible = false
			#label.text = detected.label

			
