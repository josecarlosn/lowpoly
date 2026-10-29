extends Control

@export var radius := 3

@export var color := Color.WHITE
@onready var label: Label = %Label

func _draw():
	draw_circle(size , radius, color)

func _ready():
	size = Vector2(radius * 1, radius * 1)

func _process(delta: float) -> void:
	if not label.visible:
		self.visible = true
	else:
		self.visible = false
