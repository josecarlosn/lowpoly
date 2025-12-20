extends RayCast3D

@onready var label = $Label
@onready var crosshair = $Crosshair
@onready var note_control: Control = %NoteControl
@onready var note_texture: TextureRect = %NoteTexture
@onready var note_label: RichTextLabel = %NoteLabel
@onready var player: CharacterBody3D = $"../../.."
@onready var cross_hair_action_label: Label = $Label/CrossHairActionLabel
@onready var note_title: Label = $"../NoteLayer/NoteControl/NoteTitle"




func _ready() -> void:
	note_control.visible = false
	add_exception(player) #Faz do jogador uma exceção.

func _process(delta: float) -> void:
	cross_hair_action_label.text = ""
	label.text = ""
	#note_title.text = ""
	crosshair.visible = true
	
	if is_colliding():
		var detected = get_collider()
		if detected is Interactable:
			if detected.action == "Read":
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
						note_title.text = detected.title
					else: 
						label.visible = true
						player.can_move = true
						note_control.visible = false	
						
			elif detected.action == "Lamp":
				cross_hair_action_label.text = detected.action
				crosshair.visible = false
				if detected.is_on == true:
					label.text = detected.label_on
				elif detected.is_on == false:
					label.text = detected.label_off
				if Input.is_action_just_pressed("use"):
					detected.is_on = !detected.is_on
					if detected.is_on:
						detected.light.visible = true
					else:
						detected.light.visible = false
						
