extends Interactable
@onready var light: OmniLight3D = $"../../HallLight"
@export var is_on := false
@export var label_on := "Desligar"
@export var label_off := "Ligar"
@export var title := ""
@export var content := ""
@export var action := "Lamp"
