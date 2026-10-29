extends Control
@onready var label: Label = %Label

#func _process(delta: float) -> void:
	#if not label.visible:
		#self.visible = true
	#else:
		#self.visible = false
		#
