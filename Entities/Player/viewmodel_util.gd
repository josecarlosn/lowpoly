class_name ViewmodelUtil
extends RefCounted

const VIEWMODEL_LAYER := 2

## Move o node e todos os filhos para a camada do viewmodel (ou de volta ao mundo).
static func apply(node: Node, enabled: bool) -> void:
	if node is VisualInstance3D:
		node.set_layer_mask_value(1, not enabled)
		node.set_layer_mask_value(VIEWMODEL_LAYER, enabled)
		if node is GeometryInstance3D and enabled:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		apply(child, enabled)
