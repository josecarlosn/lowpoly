extends Node

@export var security_scene: PackedScene
@export var tv_screen: MeshInstance3D

@onready var viewport: SubViewport = %ScreenViewPort


func _ready() -> void:
	setup_security_camera()


func setup_security_camera() -> void:

	# 1. Validar referências
	if security_scene == null:
		push_error("Security Scene não configurada!")
		return

	if tv_screen == null:
		push_error("TV Screen não configurada!")
		return

	# 2. Configurar o mundo independente
	viewport.own_world_3d = true
	viewport.size = Vector2i(320, 240)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# 3. Instanciar a outra fase dentro do SubViewport
	var security_level = security_scene.instantiate()
	viewport.add_child(security_level)

	# 4. Encontrar a câmera da outra fase
	var security_camera := security_level.find_child(
		"SecurityCamera", true, false
	) as Camera3D

	if security_camera == null:
		push_error("Não encontrei uma Camera3D chamada SecurityCamera!")
		return

	# 5. Ativar a câmera no SubViewport
	security_camera.make_current()

	# 6. Criar material para a televisão
	var material := StandardMaterial3D.new()

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_texture = viewport.get_texture()

	# 7. Aplicar material à tela
	tv_screen.material_override = material
