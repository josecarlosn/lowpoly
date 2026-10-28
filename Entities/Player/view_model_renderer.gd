
extends CanvasLayer

@export var main_camera: Camera3D
@export var viewmodel_fov: float = 65.0

@onready var vm_camera: Camera3D = \
	$SubViewportContainer/SubViewport/ViewModelCamera


func _ready() -> void:
	if main_camera == null:
		push_error("A câmera principal não foi atribuída.")
		return

	# A câmera principal não desenha o viewmodel.
	main_camera.set_cull_mask_value(
		ViewmodelUtil.VIEWMODEL_LAYER,
		false
	)

	# A câmera do viewmodel desenha somente sua camada.
	vm_camera.cull_mask = 0
	vm_camera.set_cull_mask_value(
		ViewmodelUtil.VIEWMODEL_LAYER,
		true
	)

	vm_camera.fov = viewmodel_fov
	vm_camera.near = 0.01

	_setup_environment()

	# Atualiza a câmera depois do movimento do jogador.
	process_priority = 100


func _process(_delta: float) -> void:
	if main_camera != null:
		vm_camera.global_transform = main_camera.global_transform


func _setup_environment() -> void:
	var env: Environment = null
	var world_env := get_tree().current_scene.find_child(
		"WorldEnvironment",
		true,
		false
	) as WorldEnvironment

	if world_env != null and world_env.environment != null:
		env = world_env.environment.duplicate()
		vm_camera.attributes = world_env.camera_attributes
	elif main_camera.environment != null:
		env = main_camera.environment.duplicate()
		vm_camera.attributes = main_camera.attributes
	else:
		env = Environment.new()

	# Preserva a iluminação ambiente quando ela depende do fundo.
	if env.ambient_light_source == Environment.AMBIENT_SOURCE_BG:
		match env.background_mode:
			Environment.BG_SKY:
				env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY

			Environment.BG_COLOR:
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.ambient_light_color = env.background_color
				env.ambient_light_energy = env.background_energy_multiplier

	# Mantém o fundo do SubViewport transparente.
	env.background_mode = Environment.BG_CLEAR_COLOR

	vm_camera.environment = env
