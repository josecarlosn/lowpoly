extends Control

@onready var start: Button = %START
@onready var start_arrow: TextureRect = %StartLabel
@onready var quit: Button = %QUIT
@onready var quit_arrow: TextureRect = %QuitLabel

func _ready() -> void:
	start_arrow.hide()
	quit_arrow.hide()
	
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Home/home_sweet_home.tscn")
	
func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_start_mouse_entered() -> void:
	start_arrow.show()
	quit_arrow.hide()
func _on_start_mouse_exited() -> void:
	start_arrow.hide()
func _on_quit_mouse_entered() -> void:
	start_arrow.hide()
	quit_arrow.show()
func _on_quit_mouse_exited() -> void:
	quit_arrow.hide()
