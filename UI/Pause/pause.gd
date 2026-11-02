extends Control

@onready var resume: Button = %RESUME
@onready var menu: Button = %MENU
@onready var quit: Button = %QUIT
@onready var resume_arrow: TextureRect = %ResumeLabel
@onready var menu_arrow: TextureRect = $VBoxContainer/MENU/MenuLabel
@onready var quit_arrow: TextureRect = %QuitLabel

var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	# O menu precisa continuar funcionando com o jogo pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS

	hide()

	# As setas seguem o foco (teclado, controle e mouse).
	for button in [resume, menu, quit]:
		button.focus_entered.connect(_update_arrows)
		button.focus_exited.connect(_update_arrows)

	_update_arrows()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return

	get_viewport().set_input_as_handled()

	if get_tree().paused:
		resume_game()
	elif _can_pause():
		pause_game()


func _can_pause() -> bool:
	var player = Global.player

	# Sem player (menu principal, loading) não existe pause.
	if not is_instance_valid(player):
		return false

	# Com o inventário aberto, o ESC fecha o inventário primeiro.
	if player.player_input.in_inventory:
		return false

	return player.can_pause


func pause_game() -> void:
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	show()
	resume.grab_focus()


func resume_game() -> void:
	get_tree().paused = false
	hide()
	Input.mouse_mode = _previous_mouse_mode


func _update_arrows() -> void:
	resume_arrow.visible = resume.has_focus()
	menu_arrow.visible = menu.has_focus()
	quit_arrow.visible = quit.has_focus()


# --- Mouse: ao passar por cima o botão recebe o foco (e a seta aparece) ---

func _on_resume_mouse_entered() -> void:
	resume.grab_focus()


func _on_resume_mouse_exited() -> void:
	pass


func _on_menu_mouse_entered() -> void:
	menu.grab_focus()


func _on_menu_mouse_exited() -> void:
	pass


func _on_quit_mouse_entered() -> void:
	quit.grab_focus()


func _on_quit_mouse_exited() -> void:
	pass


# --- Botões ---

func _on_resume_pressed() -> void:
	resume_game()


func _on_menu_pressed() -> void:
	# Despausar ANTES de trocar de cena, senão o menu principal abre congelado.
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://UI/MainMenu/main_menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
