
extends Node3D

func _ready() -> void:
	print("Nó do modelo: ", get_path())
	
	var nodes := find_children("*", "", true, false)

	print("Quantidade de filhos: ", nodes.size())

	for node in nodes:
		print(node.get_path(), " | Tipo: ", node.get_class())
	#debug_lamp_lighting()
#
#func debug_lamp_lighting() -> void:
	#var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
#
	#if mesh_instance == null:
		#return
#
	#print("Camadas do modelo: ", mesh_instance.layers)
#
	#var lights := get_tree().current_scene.find_children(
		#"*", "Light3D", true, false
	#)
#
	#for node in lights:
		#var light := node as Light3D
#
		#print(
			#"Luz: ", light.name,
			#" | Máscara: ", light.light_cull_mask,
			#" | Energia: ", light.light_energy,
			#" | Distância até a lâmpada: ",
			#light.global_position.distance_to(mesh_instance.global_position)
		#)
