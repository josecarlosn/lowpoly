# Movimentações da reorganização

Cada linha: **de** → **para** (arquivos/pastas; `.import` e `.uid` acompanham cada arquivo). Caminhos relativos a `res://`.

| De | Para |
|---|---|
| `Godot_v3.6-stable_win64.exe.zip` | `_Archive/Zips/Godot_v3.6-stable_win64.exe.zip` |
| `PS1-shaders-for-godot-main.zip` | `_Archive/Zips/PS1-shaders-for-godot-main.zip` |
| `ttttt.zip` | `_Archive/Zips/ttttt.zip` |
| `ttttt2.zip` | `_Archive/Zips/ttttt2.zip` |
| `Assets/Models/Trees/tree_winter.zip` | `_Archive/Zips/tree_winter.zip` |
| `Assets/Fonts/not-jam-mono-clean-13-zip.zip` | `_Archive/Zips/not-jam-mono-clean-13-zip.zip` |
| `Entities/Player/interaction/interaction_component_backup.gd` | `_Archive/Legacy/interaction_component_backup.gd` |
| `Entities/Player/interaction` | `Entities/Player/Interaction` |
| `Entities/Player/character_body_3d.gd` | `Entities/Player/Scripts/character_body_3d.gd` |
| `Entities/Player/player_input.gd` | `Entities/Player/Scripts/player_input.gd` |
| `Entities/Player/player_move.gd` | `Entities/Player/Scripts/player_move.gd` |
| `Entities/Player/player_camera_3d.gd` | `Entities/Player/Scripts/player_camera_3d.gd` |
| `Entities/Player/crosshair_contition.gd` | `Entities/Player/Scripts/crosshair_contition.gd` |
| `Entities/Player/debug_controller.gd` | `Entities/Player/Scripts/debug_controller.gd` |
| `Entities/Player/floor_type_ray.gd` | `Entities/Player/Scripts/floor_type_ray.gd` |
| `Entities/Player/lamp.gd` | `Entities/Player/Scripts/lamp.gd` |
| `Objects/Test` | `Entities/Items/Collectables` |
| `Objects/lamp.png` | `Assets/Textures/Items/lamp.png` |
| `teste_wood_fancy_04.jpg` | `Assets/Textures/Items/teste_wood_fancy_04.jpg` |
| `teste_door_professional_01.png` | `Assets/Textures/Testes/teste_door_professional_01.png` |
| `tree_winter.tscn` | `Entities/Props/Trees/tree_winter.tscn` |
| `house.gltf` | `Assets/Models/House/house.gltf` |
| `house0.bin` | `Assets/Models/House/house0.bin` |
| `home_sweet_home.gltf` | `Assets/Models/House/home_sweet_home.gltf` |
| `home_sweet_home0.bin` | `Assets/Models/House/home_sweet_home0.bin` |
| `home_sweet_home_protptype.gltf` | `Assets/Models/House/home_sweet_home_protptype.gltf` |
| `home_sweet_home_protptype0.bin` | `Assets/Models/House/home_sweet_home_protptype0.bin` |
| `abajour.blend` | `Assets/Models/Props/abajour.blend` |
| `teste.blend` | `Assets/Models/Testes/teste.blend` |
| `teste.glb` | `Assets/Models/Testes/teste.glb` |
| `hterrain_psx.gdshader` | `Assets/Shaders/hterrain_psx.gdshader` |
| `terrain_psx.gdshader` | `Assets/Shaders/terrain_psx.gdshader` |
| `object_ps1_shader.gdshader` | `Assets/Shaders/object_ps1_shader.gdshader` |
| `Scenes/PSX.gdshader` | `Assets/Shaders/PSX.gdshader` |
| `Entities/Player/Inventory/vcr_shader.gdshader` | `Assets/Shaders/vcr_shader.gdshader` |
| `PS1-shaders-for-godot-main/PS1-shaders-for-godot-main` | `Assets/Shaders/PS1` |
| `Sounds/DoorSounds/image-removebg-preview.png` | `Assets/Textures/Misc/image-removebg-preview.png` |
| `Sounds` | `Assets/Audio` |
| `Scenes/home_sweet_home/geladeira vela.mp3` | `Assets/Audio/Ambient/geladeira vela.mp3` |
| `textures` | `Assets/Textures/Common` |
| `TexturesBlender/textures` | `Assets/Textures/House` |
| `Terrains/Textures` | `Assets/Textures/Terrain` |
| `Scenes/main_slot0_albedo_bump.png` | `Assets/Textures/Terrain/FromScenes/main_slot0_albedo_bump.png` |
| `Scenes/main_slot0_normal_roughness.png` | `Assets/Textures/Terrain/FromScenes/main_slot0_normal_roughness.png` |
| `trest.tres` | `Resources/MeshLibraries/trest.tres` |
| `terrainy_demo.tscn` | `Scenes/Testes/terrainy_demo.tscn` |
| `Scenes/test.tscn` | `Scenes/Testes/test.tscn` |
| `Scenes/home_sweet_home` | `Scenes/Home` |
| `*.blend1` (todos) | `_Archive/BlenderBackups/<caminho com __>` |
| `*.tmp` (5 arquivos) | `_Archive/Tmp/<caminho com __>` |

Obs.: `Scenes/main_slot0_*.png` foram para `Assets/Textures/Terrain/FromScenes/` porque já existia um `main_slot0_normal_roughness.png` (outro arquivo, de tamanho diferente) em `Terrains/Textures/`.

Correções automáticas: 14 referências `res://` com maiúscula/minúscula errada foram ajustadas; `key.tscn` e `key2.tscn` deixaram de usar `load_path` em `.godot/imported`.
