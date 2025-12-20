extends Interactable

@export var is_on := false
@onready var light: OmniLight3D = $"../../LivingRoomLight"
@export var label_on := "Desligar"
@export var label_off := "Ligar"
@export var title := ""
@export var content := ""
@export var action := "Lamp"
