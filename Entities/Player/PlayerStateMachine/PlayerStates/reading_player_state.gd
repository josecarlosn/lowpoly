class_name ReadingPlayerState extends State
@onready var state_machine: StateMachine = $".."

@onready var note_texture: TextureRect = %NoteTexture
@onready var note_label: RichTextLabel = %NoteLabel
@onready var note_title: Label = $"../../head/Camera3D/NoteLayer/NoteControl/NoteTitle"
@onready var note_control: Control = %NoteControl



var can_exit:bool = false
func enter():
	var detected = Global.player.detected
	show_content(detected)
	can_interact = false
	Global.player.velocity = Vector3.ZERO
	Global.player.can_move = false
	
	await get_tree().create_timer(0.25).timeout
	can_exit = true
func update(_delta: float) -> void:
	if Input.is_action_just_pressed("use") and can_exit:
		transition.emit(state_machine.PREVIOUS_STATE.name)
func exit():
	Global.player.can_move = true
	can_exit = false
	hide_content()
	print("Sai da leitura")


func show_content(detected):
	note_texture.texture = load(detected.texture_content)
	note_control.visible = true
	note_label.text = detected.content
	note_title.text = detected.title
func hide_content():
	note_control.visible = false
