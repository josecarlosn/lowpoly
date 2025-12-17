extends Control

@export var radius := 1
@export var color := Color.WHITE

func _draw():
	draw_circle(size , radius, color)

func _ready():
	size = Vector2(radius * 1, radius * 1)
