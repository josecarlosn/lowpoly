# Guia de continuidade — Sistema de Inventário

Projeto **lowpoly** · Godot **4.6** · GDScript

> **Como ler este guia**
> - **Parte 1** descreve, com precisão de função e linha de raciocínio, como o inventário funciona *hoje*.
> - **Parte 2** corrige a fundação (sem isso, itens equipáveis e drop vão herdar os bugs atuais).
> - **Parte 3** mostra como criar itens **usáveis, equipáveis e inspecionáveis** em cima do `ItemData` que você já tem.
> - **Parte 4** implementa **drop** (manual e por tabela de loot).
> - **Parte 5** é o checklist de ordem de implementação.
>
> Marcadores nos blocos de código: `# ✅ já existe` · `# ✏️ alterar` · `# 🆕 novo arquivo`.
> Todos os caminhos já usam a **nova organização de pastas** (Parte 0).

---

## 0. A organização nova do projeto

O zip foi reorganizado sem quebrar referências: todo `res://...` dentro de `.tscn`, `.tres`, `.gd`, `.import`, `.gdshader` e `project.godot` foi reescrito, e os `.uid` / `.import` acompanham cada arquivo movido (o Godot mantém os UIDs).

```
res://
├── Assets/
│   ├── Audio/            (Ambient, DoorSounds, FootSteps)
│   ├── Fonts/
│   ├── Models/           (House, Props, Testes, Trees)
│   ├── Shaders/          (PSX, vcr_shader, object_ps1, terrain…, PS1/)
│   └── Textures/         (Common, House, Items, Terrain, Testes, Misc)
├── Entities/
│   ├── House/
│   ├── Items/Collectables/   ← key.tscn, key2.tscn (antes em Objects/Test)
│   ├── Player/
│   │   ├── Interaction/      ← antes "interaction" (minúsculo)
│   │   ├── Inventory/        ← item_data, slot, controller, Actions/
│   │   ├── PlayerStateMachine/
│   │   └── Scripts/          ← character_body_3d, player_input, player_move, camera, lamp…
│   ├── Props/Trees/
│   └── Stages/LivingRoom/…
├── Globals/Scripts/          (Global.gd = autoload, state.gd)
├── Resources/MeshLibraries/
├── Scenes/                   (main, Home/, Testes/, snow_particles…)
├── Terrains/                 (data.hterrain, height.res…)
├── UI/                       (CrossHair, Inspector, InventoryUI)
├── addons/                   (intocado)
└── _Archive/                 (.gdignore → o Godot não importa)
	├── Zips/  BlenderBackups/  Tmp/  Legacy/
```

**O que foi feito além de mover:**

| Ação | Detalhe |
|---|---|
| 14 referências com caixa errada corrigidas | Ex.: `res://globals/...` (o autoload `Global`) apontava para a pasta `Globals`; e `interaction_controller.tscn` apontava para `Interaction/` enquanto a pasta era `interaction/`. Funciona no Windows, **quebra em Linux/exportação**. Agora todas batem exatamente. |
| `key.tscn` e `key2.tscn` | O ícone do item estava gravado como `load_path = "res://.godot/imported/....ctex"`. Esse caminho contém o **hash do caminho original** do arquivo; ao mover a imagem o hash muda e o ícone sumiria. Troquei por referência normal (`ext_resource` com UID) à imagem de origem. |
| Backups/lixo → `_Archive/` | `*.blend1`, `*.tmp` (3 do `player.tscn`, 2 do `main.tscn`), 5 `.zip` (inclui `Godot_v3.6-stable_win64.exe.zip`, **34 MB**), `interaction_component_backup.gd`. Nada foi apagado. |

Lista completa De → Para em `Docs/MOVIMENTACOES.md`.

**Pastas novas que este guia pede para você criar (conforme avançar):**

```
Resources/Items/          ← um .tres por item (ItemData)
Resources/Loot/           ← tabelas de loot (LootTable)
Entities/Items/Pickups/   ← item_pickup.tscn (cena base de item no mundo)
Entities/Items/Loot/      ← item_spawner.gd, loot_entry.gd, loot_table.gd, loot_dropper.gd
UI/Inspector/             ← já existe (inspector.tscn está vazio; vamos usá-lo)
```

---

## 1. Como o inventário funciona hoje

### 1.1 Mapa dos arquivos

| Arquivo | `class_name` | Papel |
|---|---|---|
| `Entities/Player/Inventory/item_data.gd` | `ItemData` (Resource) | Dados de um item: `name`, `description`, `item_icon`, `action_data`. Tem também `var item_model: PackedScene` (**sem `@export`, nunca usado**). |
| `Inventory/Actions/action_data.gd` | `ActionData` (Resource) | Base das ações. Enum `ActionType {INVALID, CONSUMABLE, EQUIPABLE, INSPECTABLE}` + `var action_type` (não exportada). |
| `Actions/consumable_action.gd` | `ConsumableAction` | `@export modifier_value: int`. `_init()` define `action_type = CONSUMABLE`. |
| `Actions/equipable_action.gd` | `EquipableAction` | `@export one_time_use: bool = true`, `@export success_message: String`. |
| `Actions/inspectable_action.gd` | `InspectableAction` | Só define o tipo. |
| `Inventory/inventory_slot.gd` + `slot.tscn` | `InventorySlot` | Um slot (um `Button` com ícone, número e animação "floating"). Guarda `slot_data`, `slot_filled`, `slot_title`, `slot_description`. |
| `Inventory/inventory_controller.gd` + `inventory_controller.tscn` | `InventoryController` | Instancia os slots, mostra/esconde a UI, mostra título/descrição do slot focado e implementa `pickup_item()`. |
| `Interaction/InteractionController/interaction_controller.gd` | — (sem class_name) | Raycast de interação; liga a coleta ao inventário. |
| `Interaction/InteractableScripts/collectable_interaction_component.gd` | `CollectableInteraction` | Componente de um objeto **coletável**. Emite `item_collected`. |
| `Interaction/InteractableScripts/door_interaction_component.gd` | `DoorInteraction` | Componente de **porta** (tem `key_id`, ainda não usado). |
| `Scripts/player_input.gd` | `PlayerInput` | Lê as ações de input. Guarda `in_inventory`, `is_interacting`. |
| `Globals/Scripts/Global.gd` | — (autoload `Global`) | Só tem `var player: Player`. |

### 1.2 Árvore de cena (como tudo se encaixa no `player.tscn`)

```
Player (CharacterBody3D, character_body_3d.gd, class Player)
├── head/Camera3D (PlayerCamera)
│   ├── interactRay (RayCast3D, unique)      target (0,0,2) · mask 24 = camadas 4 e 5
│   │   ├── Label (unique)                    ← texto "hover" do objeto
│   │   └── playerHand (Marker3D, unique)     ← "mão" usada pela porta e (futuro) item equipado
│   └── InventoryTarget (Node3D, unique)      ← alvo da animação de coleta (hoje código comentado)
├── PlayerInput, PlayerMovement, StateMachine…
├── InventoryController   (instância de inventory_controller.tscn, unique)
│   └── InventoryCanvasLayer (CanvasLayer)
│       ├── PlayerInventoryUI (Control)  ← **inventory_controller.gd está AQUI** (não na raiz)
│       │   ├── Panel ─ InventoryTitle · MarginContainer/GridContainer (%, 5 colunas, 800×250)
│       │   │         └ Tools (Label: "[E]:EQUIP  [G]:DROP  [TAB] EXIT")
│       │   └── ItemContent/ItemTitle (%) · ItemDescription (%)
│       └── InventoryShader (ColorRect com vcr_shader)
└── InteractionController (instância, unique, interaction_controller.gd)
```

Dois detalhes que mordem:

1. A raiz `InventoryController` (Node) **não tem script**. O script `InventoryController` está no `PlayerInventoryUI`. Por isso o `InteractionController` o alcança com o caminho longo
   `%InventoryController/InventoryCanvasLayer/PlayerInventoryUI`.
2. O nome único `%X` só resolve a partir do dono da cena. De fora da cena do inventário você não consegue escrever `%PlayerInventoryUI` — use o caminho longo (vamos encapsulá-lo no `Player`, seção 2.6).

### 1.3 Fluxo completo de coleta (passo a passo)

Cena de um item no mundo (`key.tscn`):

```
Key (Node3D)
└── KeyRigidBody (RigidBody3D, collision_layer = 8 → camada 4 "interactables")
	├── MeshInstance3D, CollisionShape3D
	└── InteractionComponent   ← nó com NOME FIXO; script = CollectableInteraction
		  collectable_ref = ".." (o RigidBody)
		  item_data = ItemData embutido (sub_resource) com name/description/icon/action_data
```

A sequência, quadro a quadro (tudo em `_physics_process` do `interaction_controller.gd`):

1. **Foco.** `interact_ray.get_collider()` devolve o `KeyRigidBody`. Sem `current_object`, o controller faz `potential_object.get_node_or_null("InteractionComponent")`. *Regra implícita do projeto: o componente precisa ser filho direto do corpo que o raio acerta e se chamar exatamente `InteractionComponent`.*
2. Se for `CollectableInteraction` e ainda não conectado, conecta `item_collected → _on_item_collected`. Chama `_focus()` → `Label.text = hover_label`.
3. **Clique.** `PlayerInput.poll()` seta `is_interacting = Input.is_action_pressed("primary")` (botão esquerdo, **segurado**, não "just pressed"). Se `can_interact` e `is_interacting`: `current_object = potential_object` e `pre_interact()`.
4. **Frame seguinte.** Com `current_object` setado, valida distância (> 3.0 m cancela) e, se ainda clicando, chama `interact_component.interact()` → `CollectableInteraction._try_interact()`.
5. `_try_interact()` faz `emit_signal("item_collected", collectable_ref)` e **depois** `can_interact = false; is_collecting = true`.
6. `_on_item_collected(item)` (no controller) pega `item.get_node_or_null("InteractionComponent").item_data`, emite `invent_on_item_collected(item_data)` (conectado em `_ready` a `inventory_controller.pickup_item`) e em seguida **`item.queue_free()`**.
7. `InventoryController.pickup_item(item_data)`:
   - se `inventory_full` → `print` e `return`;
   - senão percorre `inventory_slots`, acha o primeiro `not slot_filled`, chama `slot.fill_slot(item_data)`, **copia** `slot_title` e `slot_description` do `item_data` para o slot (de fora do slot), recalcula `inventory_full` e `return`.
8. `InventorySlot.fill_slot()` guarda `slot_data`, `slot_filled = true` e troca `icon.texture`.

### 1.4 Dados e estado

- **Fonte da verdade do inventário = os próprios nós `InventorySlot`.** Não existe um array de dados separado da UI. `inventory_slots: Array[InventorySlot]` só guarda referências aos nós.
- Cada slot guarda **uma referência** a um `ItemData`; **não existe quantidade**, nem empilhamento, nem instância por-item.
- `item_slots_count = 5` é fixo no script e o `GridContainer` tem `columns = 5`: os dois precisam ser mantidos em sincronia à mão.
- **Nada é salvo.** Fechou o jogo, perdeu tudo.
- `ItemData` hoje vive **embutido dentro da cena** do objeto (`sub_resource`). Todas as instâncias de `key.tscn` compartilham o mesmo `ItemData` (sub-resources de um `PackedScene` são compartilhados). Consequência: **nunca altere um `ItemData` em runtime** (durabilidade, quantidade…) — mudaria o item de todo mundo.

### 1.5 Entrada, foco e UI

| Ação (`project.godot`) | Tecla | Uso atual |
|---|---|---|
| `inventory` | **Tab** | `PlayerInput.poll()` inverte `in_inventory` **e** `player.can_move`. |
| `ui_left/right/up/down` | **A/D/W/S** (+ D-pad/analógico) | Foram sobrescritos: movem o player **e** navegam o foco dos slots. O que impede o player de andar com a UI aberta é `can_move = false`. |
| `primary` | Botão esquerdo | Interação (segurado). |
| `use` | **E** | Hoje só o `ReadingPlayerState` (legado) usa. |
| `lamp` | F | Liga/desliga a `SpotLight3D` (`lamp.gd`). |
| `drop` | — | **Não existe**, embora o label da UI diga `[G]:DROP`. |

Como a UI funciona: `PlayerInventoryUI._process()` roda **todo frame**: `who_is_on_focus()` copia título/descrição do slot focado para os labels; `handle_inventory_visibility()` faz `inventory_canvas_layer.visible = player.player_input.in_inventory`; se ninguém tem foco, `grid.get_child(0).grab_focus()`. O foco por teclado é o que seleciona "o item atual" — **o item selecionado é sempre o slot focado**. Vamos reaproveitar isso para usar/dropar.

### 1.6 O que existe só como "casca" (declarado, mas ninguém usa)

| Peça | Situação |
|---|---|
| `ItemData.action_data` | Guardado, **nunca lido**. Nenhum código executa `ActionData`. As três subclasses só têm campos. |
| `ItemData.item_model` | Sem `@export` (não aparece no Inspector), nunca lido. |
| `ConsumableAction.modifier_value` | Sem efeito (não há sistema de vida/atributos). |
| `EquipableAction.one_time_use` / `success_message` | Sem efeito. |
| `InventorySlot` — `ont_item_swapped`, `on_double_clicked`, `on_item_right_clicked` | Declarados, **nunca emitidos nem conectados**. (Note o typo `ont_`.) |
| `InventorySlot.inventory_slot_id` | Fica `-1` para sempre; ninguém atribui. |
| `InventorySlot._get_drag_data()` | Cria `preview`, mas **retorna `null`** → o drag nunca começa. `_can_drop_data` retorna `false`. |
| `DoorInteraction.key_id` | Existe, mas a porta **nunca consulta o inventário**. `is_locked` só congela o `RigidBody3D`. |
| `Tools` label (`[E]:EQUIP [G]:DROP`) | Texto estático. |
| `ReadingPlayerState`, `Lv_Note`, `Lv_IdentityCard`, `Lv_Lamp` | **Legado quebrado:** estendem `Interactable`, e **não encontrei** nenhum `class_name Interactable` no projeto; o `player.tscn` não tem nó `NoteLayer` nem instancia o `ReadingPlayerState`. Não fazem parte do fluxo novo. |

### 1.7 Bugs e riscos encontrados (ordem de gravidade)

1. 🔴 **Item é destruído com o inventário cheio.** `pickup_item()` retorna `void`; o `_on_item_collected()` chama `item.queue_free()` **sempre**, mesmo quando o inventário recusou. O item some do mundo e não entra no inventário.
2. 🔴 **Não dá para "devolver" o item ao mundo dentro do handler:** `_try_interact()` zera `can_interact` *depois* do `emit`, então qualquer tentativa de reativar o componente dentro do handler é sobrescrita (importante para a correção do item 1).
3. 🟠 **`queue_free()` só no `RigidBody3D`** (`collectable_ref`). O `Key` (Node3D raiz) fica vazio na cena para sempre.
4. 🟠 **Interação com a UI aberta.** `_physics_process` não olha `in_inventory`; com o inventário aberto o clique ainda coleta o que estiver na mira.
5. 🟠 **Estado duplicado e fora do dono:** `slot_title`/`slot_description` são preenchidos pelo *controller*, não por `fill_slot()`. Para limpar um slot você teria que lembrar de zerar 4 campos em dois lugares.
6. 🟠 **`who_is_on_focus()` assume que todo foco é um `InventorySlot`** (`on_focus_slot.slot_title`). Se outro `Control` pegar foco, dá erro.
7. 🟡 **`ItemData` embutido e compartilhado** (ver 1.4) e **sem `id`** — por isso porta/chave não conseguem se identificar.
8. 🟡 `InventorySlot` faz `@onready var player = Global.player`: nesse momento `Global.player` ainda é `null` (o `Player` seta em seu `_ready`, que roda depois dos filhos). Não é usado, mas é armadilha.
9. 🟡 `item_slots_count` (5) × `GridContainer.columns` (5) duplicados.
10. 🟡 `_process` com polling por frame: funciona, mas o certo é reagir a eventos (`inventory_changed`, abrir/fechar).

---

## 2. Fundação: o que ajustar antes de criar itens e drop

Faça esta parte primeiro. São mudanças pequenas e cada uma é testável isolada.

### 2.1 `ItemData` — dar identidade e ligação com o mundo

`Entities/Player/Inventory/item_data.gd`

```gdscript
extends Resource
class_name ItemData

@export_category("Identidade")
## ID único e estável. É o que portas, receitas, loot e save usam. Ex.: &"key_front_door"
@export var id: StringName
@export var name: String
@export_multiline var description: String
@export var item_icon: Texture2D                 # ✏️ era Texture (Texture2D é compatível)

@export_category("Mundo")
## Cena do item no chão (o "pickup"). É String de propósito — ver 2.2 (ciclo de dependência).
@export_file("*.tscn") var world_scene_path: String   # 🆕 substitui `var item_model`

@export_category("Regras")
@export var droppable: bool = true               # 🆕
@export var stackable: bool = false              # 🆕 (só reservado; empilhamento na Parte 6)
@export var max_stack: int = 1                   # 🆕

@export_category("Ação")
@export var action_data: ActionData              # ✅ já existe
```

### 2.2 Extraia os `ItemData` para arquivos `.tres` — e entenda o ciclo

1. No Inspector de `key.tscn`, clique no `item_data` → menu do recurso → **Save As…** → `res://Resources/Items/key_front_door.tres`. Repita para `key2.tscn`.
2. Preencha `id` (ex.: `key_front_door`, `key_room_2`).
3. Agora os loot tables (Parte 4) também conseguem apontar para o item pelo Inspector.

**Por que `world_scene_path` é `String` e não `PackedScene`:** `key.tscn` referencia o `key_front_door.tres` (para saber qual item é) e o `.tres` precisa apontar de volta para a cena (para o drop saber o que instanciar). Referência de recurso nos dois sentidos é **dependência cíclica**: o Godot recusa carregar com o erro *"Another resource is loaded from path … (possible cyclic resource inclusion)"*. Um `String` com o caminho não cria dependência; o carregamento acontece só na hora do drop, com `load()`.

> Trade-off: se você mover a cena pelo FileSystem do editor, o Godot atualiza referências de recurso mas **não** strings. Se mover um pickup, corrija o `world_scene_path`.

### 2.3 `InventorySlot` — o slot passa a ser dono do seu estado

`inventory_slot.gd` (✏️ trocar `fill_slot`, 🆕 `clear_slot`, remover o `@onready player`)

```gdscript
extends Control
class_name InventorySlot

@onready var icon: TextureRect = %InventoryTextureRect
@onready var num_slot: Label = %NumSlot

var slot_title: String = ""
var slot_description: String = ""
var inventory_slot_id: int = -1            # ✏️ agora o controller atribui
var empty_icon: Texture = preload("uid://ckirht210g37o")
var slot_filled: bool = false
var slot_data: ItemData

func _ready() -> void:
	icon.texture = empty_icon

func fill_slot(item_data: ItemData) -> void:        # ✏️
	slot_data = item_data
	slot_filled = item_data != null
	slot_title = item_data.name if slot_filled else ""
	slot_description = item_data.description if slot_filled else ""
	icon.texture = item_data.item_icon if slot_filled else empty_icon

func clear_slot() -> void:                          # 🆕
	fill_slot(null)
```

Mantenha os signals e o drag/drop como estão por enquanto; só mexa neles na Parte 6.

### 2.4 `InventoryController` — API de verdade (add / remove / buscar) + sinais

`inventory_controller.gd` — versão base completa (✏️ substitui o arquivo):

```gdscript
extends Control
class_name InventoryController

signal item_added(item: ItemData, slot_index: int)
signal item_removed(item: ItemData, slot_index: int)
signal inventory_changed

@export var item_slots_count: int = 5

@onready var inventory_canvas_layer: CanvasLayer = $".."
@onready var inventory_grid: GridContainer = %GridContainer
@onready var item_title: Label = %ItemTitle
@onready var item_description: RichTextLabel = %ItemDescription

var inventory_slot_prefab: PackedScene = load("res://Entities/Player/Inventory/slot.tscn")
var inventory_slots: Array[InventorySlot] = []
var inventory_full: bool = false


func _ready() -> void:
	inventory_grid.columns = item_slots_count          # ✏️ uma fonte só para 5 colunas
	for i in item_slots_count:
		var slot := inventory_slot_prefab.instantiate() as InventorySlot
		inventory_grid.add_child(slot)
		slot.inventory_slot_id = i
		slot.num_slot.text = str(i + 1)
		inventory_slots.append(slot)


func _process(_delta: float) -> void:
	var player := Global.player
	if player == null:
		return
	inventory_canvas_layer.visible = player.player_input.in_inventory
	if not inventory_canvas_layer.visible:
		return
	_refresh_description()
	if get_viewport().gui_get_focus_owner() == null:
		inventory_grid.get_child(0).grab_focus()


func _refresh_description() -> void:
	var slot := get_viewport().gui_get_focus_owner() as InventorySlot   # ✏️ cast seguro
	if slot:
		item_title.text = slot.slot_title
		item_description.text = slot.slot_description


# ───────────────────────── API pública ─────────────────────────

## Retorna true se o item entrou. Quem chama DECIDE o que fazer com o objeto do mundo.
func pickup_item(item_data: ItemData) -> bool:         # ✏️ era void
	if item_data == null:
		return false
	var index := _find_free_slot()
	if index == -1:
		inventory_full = true
		print("Inventário cheio! Não foi possível coletar: ", item_data.name)
		return false
	inventory_slots[index].fill_slot(item_data)
	inventory_full = _find_free_slot() == -1
	item_added.emit(item_data, index)
	inventory_changed.emit()
	return true


func remove_at(slot_index: int) -> ItemData:           # 🆕
	if slot_index < 0 or slot_index >= inventory_slots.size():
		return null
	var slot := inventory_slots[slot_index]
	if not slot.slot_filled:
		return null
	var item := slot.slot_data
	slot.clear_slot()
	inventory_full = false
	item_removed.emit(item, slot_index)
	inventory_changed.emit()
	return item


func get_focused_slot_index() -> int:                  # 🆕 "item selecionado" = slot focado
	return inventory_slots.find(get_viewport().gui_get_focus_owner())


func find_slot_by_id(id: StringName) -> int:           # 🆕
	for i in inventory_slots.size():
		var s := inventory_slots[i]
		if s.slot_filled and s.slot_data.id == id:
			return i
	return -1


func has_item(id: StringName) -> bool:                 # 🆕
	return find_slot_by_id(id) != -1


func remove_by_id(id: StringName) -> ItemData:         # 🆕
	return remove_at(find_slot_by_id(id))


func _find_free_slot() -> int:
	for i in inventory_slots.size():
		if not inventory_slots[i].slot_filled:
			return i
	return -1
```

Notas: `Global.player` é lido na hora (não no `@onready`) pelo problema do item 8 da 1.7; `_is_inventory_full()` virou `_find_free_slot() == -1`.

### 2.5 Corrigindo a coleta (bugs 1, 2, 3 e 4)

**a)** `collectable_interaction_component.gd` — `_try_interact()` e um método para recusar:

```gdscript
func _try_interact() -> void:                          # ✏️
	if not can_collect:
		print("Cannot collect")
		return
	can_interact = false          # trava ANTES do emit (evita coletar 2x no mesmo frame)
	is_collecting = true
	item_collected.emit(collectable_ref)

func reject_collect() -> void:                         # 🆕 chamado se o inventário recusou
	can_interact = true
	is_collecting = false
```

**b)** `interaction_controller.gd`:

```gdscript
@onready var inventory_controller: InventoryController = %InventoryController/InventoryCanvasLayer/PlayerInventoryUI  # ✏️ tipado

# ✏️ REMOVA: signal invent_on_item_collected, a linha que o conecta no _ready(),
#            _add_item_to_inventory() e o _ready() inteiro (não sobra nada nele).

func _physics_process(delta: float) -> void:
	if not player:
		player = Global.player
		return
	if player.player_input.in_inventory:               # 🆕 bug 4: nada de interagir com a UI aberta
		if current_object:
			_clear_interaction()
		else:
			_unfocus()
		return
	# …resto igual ao que você já tem…

func _on_item_collected(item: Node) -> void:           # ✏️
	var ic := item.get_node_or_null("InteractionComponent") as CollectableInteraction
	if ic == null or ic.item_data == null:
		push_warning("Coletável sem InteractionComponent/item_data: " + item.name)
		return
	if inventory_controller.pickup_item(ic.item_data):
		# bug 3: libera o objeto inteiro (raiz da cena), não só o corpo
		var root := item.owner if item.owner != null else item
		root.queue_free()
	else:
		ic.reject_collect()                            # bug 1: item continua no mundo
```

> `item.owner` é a raiz da cena em que o nó foi salvo (`Key`, em `key.tscn`). Se você adotar o pickup padrão da 2.8 (raiz = `RigidBody3D`), `owner` e `item` coincidem e nada muda.

Observação: como o clique é "segurado", com inventário cheio o `print` repete a cada frame. Troque por uma mensagem na tela com *cooldown* quando for polir.

### 2.6 `Player` — acessos diretos

Em `Entities/Player/Scripts/character_body_3d.gd`, junto dos outros `@onready`:

```gdscript
@onready var inventory: InventoryController = %InventoryController/InventoryCanvasLayer/PlayerInventoryUI  # 🆕
@onready var equipment: EquipmentManager = $EquipmentManager                                               # 🆕 (Parte 3)
```

(Crie o nó `EquipmentManager` como filho do `Player` quando chegar à 3.4. Até lá, comente a segunda linha.)

### 2.7 Input: ação `drop`

*Project → Project Settings → Input Map* → adicione `drop` e atribua **G** (o label da UI já anuncia). Mantenha `use` = **E**.

> Conflito conhecido: `use` também é usada pelo `ReadingPlayerState` (legado, desconectado). Se você reativar esse estado, não deixe os dois ouvirem `use` ao mesmo tempo.

### 2.8 Pickup padrão (recomendado)

Crie `Entities/Items/Pickups/item_pickup.tscn` e use-a como base de todo item coletável:

```
ItemPickup (RigidBody3D)            collision_layer = 8 (camada 4 "interactables"), mask = 1 (wolrd)
├── MeshInstance3D                  (o modelo do item)
├── CollisionShape3D
└── InteractionComponent (Node)     script = collectable_interaction_component.gd
	  collectable_ref = ".."
	  hover_label = "Pegar"
	  item_data = (arraste o .tres de Resources/Items/)
```

Por que raiz `RigidBody3D`: (1) `queue_free()` limpa tudo, (2) `global_position` no drop move o corpo físico diretamente, (3) o raio já acerta o corpo que carrega o componente.

Nota: no `key.tscn` atual, o `InteractionComponent` é instância de `interaction_component.tscn` (que carrega o script da **porta**) com o script trocado por cima. Funciona, mas é gambiarra; no pickup novo use um `Node` simples com o script de coleta.

> **Checkpoint da Parte 2.** Teste: pegar a chave → entra no slot 1; encher os 5 slots e tentar pegar o 6º → **o item continua no chão**; abrir o inventário (Tab) e clicar com o mouse na mira → nada é coletado.

---

## 3. Criando itens usáveis, equipáveis e inspecionáveis

### 3.1 Receita geral (vale para qualquer item)

1. **`Resources/Items/<id>.tres`** → `ItemData`: `id`, `name`, `description`, `item_icon`, `world_scene_path`, `action_data`.
2. **`action_data`** → escolha o subtipo (`ConsumableAction`, `EquipableAction` ou `InspectableAction`) e preencha os campos dele.
3. **Cena de mundo** → herde/duplique `item_pickup.tscn`, ajuste mesh/collision e arraste o `.tres` em `item_data`. Coloque o caminho dessa cena em `world_scene_path`.
4. Para o drop e o loot **não precisa de mais nada**.

O que faz o item "ter comportamento" é só o `action_data`. Hoje ele não faz nada porque ninguém o executa — a 3.2 resolve isso.

### 3.2 Dar comportamento às ações (polimorfismo no `ActionData`)

Cada ação sabe se executar; o inventário só chama `execute()`.

`Inventory/Actions/item_action_context.gd` 🆕

```gdscript
extends RefCounted
class_name ItemActionContext

var player: Player
var inventory: InventoryController
var item: ItemData
var slot_index: int = -1
```

`Inventory/Actions/action_data.gd` ✏️

```gdscript
extends Resource
class_name ActionData

enum ActionType { INVALID, CONSUMABLE, EQUIPABLE, INSPECTABLE }
var action_type: ActionType = ActionType.INVALID

## Texto para a UI ("Usar", "Equipar", "Examinar").
@export var verb: String = ""

## Executa a ação. Retorna true se deu certo.
func execute(_ctx: ItemActionContext) -> bool:
	return false

## Se true, o item sai do inventário depois de uma execução bem-sucedida.
func consumes_item() -> bool:
	return false
```

Em `InventoryController` 🆕 adicione:

```gdscript
@export var inspector: ItemInspector     # preenchido na 3.5 (pode ficar vazio por enquanto)

func use_slot(index: int) -> void:
	if index < 0 or index >= inventory_slots.size():
		return
	var slot := inventory_slots[index]
	if not slot.slot_filled or slot.slot_data.action_data == null:
		return
	var ctx := ItemActionContext.new()
	ctx.player = Global.player
	ctx.inventory = self
	ctx.item = slot.slot_data
	ctx.slot_index = index
	var action := slot.slot_data.action_data
	if action.execute(ctx) and action.consumes_item():
		remove_at(index)


func _unhandled_input(event: InputEvent) -> void:
	if not inventory_canvas_layer.visible:
		return
	if inspector and inspector.is_open:          # o inspetor fecha o "use" dele primeiro
		return
	if event.is_action_pressed("use"):
		use_slot(get_focused_slot_index())
		get_viewport().set_input_as_handled()
```

### 3.3 Item **usável / consumível** (ex.: remédio, pilha)

`consumable_action.gd` ✏️

```gdscript
extends ActionData
class_name ConsumableAction

@export var modifier_value: int = 0
## Qual atributo é afetado. Ex.: &"health", &"battery".
@export var stat: StringName = &"health"

func _init() -> void:
	action_type = ActionType.CONSUMABLE
	verb = "Usar"

func execute(ctx: ItemActionContext) -> bool:
	return ctx.player.apply_stat_modifier(stat, modifier_value)

func consumes_item() -> bool:
	return true
```

Você ainda não tem sistema de atributos. O mínimo para a ação ter onde bater, no `Player`:

```gdscript
signal stat_changed(stat: StringName, value: int)
var stats := {&"health": 100, &"battery": 100}

func apply_stat_modifier(stat: StringName, amount: int) -> bool:
	if not stats.has(stat):
		push_warning("Atributo inexistente: %s" % stat)
		return false
	stats[stat] = clampi(stats[stat] + amount, 0, 100)
	stat_changed.emit(stat, stats[stat])
	return true
```

Se você já tem (ou vai ter) vida em outro lugar, é só trocar a chamada dentro de `execute()`. **Importante:** devolver `false` quando o efeito não se aplica (vida já cheia, por exemplo) impede que o item seja gasto à toa.

`.tres` de exemplo — **Pilha**: `id=battery_small` · action = `ConsumableAction { stat=&"battery", modifier_value=25, verb="Trocar pilha" }`.

### 3.4 Item **equipável** (ex.: chaves, lanterna)

"Equipar" significa: o item fica **ativo na mão** e outros sistemas consultam *"o que o player está segurando?"* (a porta consulta a chave). O inventário continua com o item no slot.

`Actions/equipable_action.gd` ✏️ (mantém seus 2 campos)

```gdscript
extends ActionData
class_name EquipableAction

## Item some do inventário quando é usado com sucesso num alvo (ex.: chave que quebra na porta).
@export var one_time_use: bool = true                # ✅ já existe
@export var success_message: String = "Success!"     # ✅ já existe
## Modelo mostrado na mão (opcional). Fica filho de player.hand.
@export var held_scene: PackedScene                  # 🆕

func _init() -> void:
	action_type = ActionType.EQUIPABLE
	verb = "Equipar"

func execute(ctx: ItemActionContext) -> bool:
	ctx.player.equipment.toggle_equip(ctx.item)
	return true
# consumes_item() continua false: quem consome é o ALVO (porta), não o ato de equipar.
```

`Entities/Player/Scripts/equipment_manager.gd` 🆕 — adicione um `Node` chamado **`EquipmentManager`** como filho do `Player` com este script:

```gdscript
extends Node
class_name EquipmentManager

signal equipped_changed(item: ItemData)

var equipped: ItemData = null
var _held_instance: Node3D = null


func _ready() -> void:
	# Espera o Player terminar o _ready (Global.player e os @onready dele só existem depois).
	await owner.ready
	Global.player.inventory.item_removed.connect(_on_item_removed)


func toggle_equip(item: ItemData) -> void:
	if has_equipped(item.id):
		unequip()
	else:
		equip(item)


func equip(item: ItemData) -> void:
	unequip()
	equipped = item
	var action := item.action_data as EquipableAction
	if action and action.held_scene:
		_held_instance = action.held_scene.instantiate() as Node3D
		Global.player.hand.add_child(_held_instance)
	equipped_changed.emit(equipped)


func unequip() -> void:
	if _held_instance:
		_held_instance.queue_free()
		_held_instance = null
	if equipped != null:
		equipped = null
		equipped_changed.emit(null)


func has_equipped(id: StringName) -> bool:
	return equipped != null and equipped.id == id


## Chamado pelo alvo (porta) quando a ação de uso do item dá certo.
func consume_equipped() -> void:
	if equipped == null:
		return
	var id := equipped.id
	unequip()
	Global.player.inventory.remove_by_id(id)


func _on_item_removed(item: ItemData, _slot_index: int) -> void:
	if has_equipped(item.id):          # dropou/gastou o item que estava na mão
		unequip()
```

Usos imediatos:

```gdscript
# lamp.gd (SpotLight do player) — a lanterna só liga se estiver equipada
if player.player_input.lamp_request and player.equipment.has_equipped(&"flashlight"):
	visible = not visible
```

`.tres` de exemplo — **Lanterna**: `id=flashlight` · `EquipableAction { verb="Equipar", one_time_use=false }`.

### 3.5 Item **inspecionável** (ex.: RG, bilhete)

A mecânica de leitura antiga está desligada (1.6). Em vez de ressuscitá-la, use o `UI/Inspector/inspector.tscn` (hoje um `Control` vazio — parece reservado exatamente para isto).

**Cena** `inspector.tscn`:

```
ItemInspector (Control, anchors Full Rect, script item_inspector.gd, visible = false)
├── ColorRect (preto ~70% alfa, mouse_filter = Ignore)
└── CenterContainer (Full Rect)
	└── VBoxContainer
		├── Title    (Label, unique name)
		├── Picture  (TextureRect, unique name, expand/keep aspect, tamanho mínimo ~400×300)
		└── Content  (RichTextLabel, unique name, fit_content)
```

Instancie `inspector.tscn` dentro de `PlayerInventoryUI` (por último, para desenhar por cima) e arraste-o no export `inspector` do controller.

`UI/Inspector/item_inspector.gd` 🆕

```gdscript
extends Control
class_name ItemInspector

@onready var title_label: Label = %Title
@onready var picture: TextureRect = %Picture
@onready var content_label: RichTextLabel = %Content

var is_open := false

func _ready() -> void:
	visible = false

func open(title: String, content: String, texture: Texture2D) -> void:
	title_label.text = title
	content_label.text = content
	picture.texture = texture
	picture.visible = texture != null
	visible = true
	is_open = true

func close() -> void:
	visible = false
	is_open = false

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("use"):
		close()
		get_viewport().set_input_as_handled()
```

`Actions/inspectable_action.gd` ✏️

```gdscript
extends ActionData
class_name InspectableAction

@export var title: String = ""
@export_multiline var content: String = ""
@export var texture_content: Texture2D

func _init() -> void:
	action_type = ActionType.INSPECTABLE
	verb = "Examinar"

func execute(ctx: ItemActionContext) -> bool:
	if ctx.inventory.inspector == null:
		push_warning("InventoryController sem inspector atribuído")
		return false
	ctx.inventory.inspector.open(title, content, texture_content)
	return true
# consumes_item() = false: examinar não gasta o item.
```

`.tres` de exemplo — **RG**: `id=id_card` · `InspectableAction { title="RG", texture_content=rg.png, content="..." }` (a imagem já está em `Entities/Stages/LivingRoom/LivingRoomTable/Lv_IdentityCard/rg.png`).

### 3.6 Ligando a chave à porta (o `key_id` que já existe)

`door_interaction_component.gd` — ramo trancado de `_try_interact()` (✏️):

```gdscript
else: # Locked door!
	var body := door_ref as RigidBody3D
	var equipment := Global.player.equipment
	if key_id != "" and equipment.has_equipped(StringName(key_id)):
		is_locked = false
		var action := equipment.equipped.action_data as EquipableAction
		interact_label = action.success_message if action else unlocked_label
		if action == null or action.one_time_use:
			equipment.consume_equipped()
		if body:
			body.freeze = false
	else:
		interact_label = locked_door_label
		if body:
			body.freeze = true
			body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
```

Na porta (`home.tscn` → `RoomDoor/InteractionComponent`): `is_locked = true`, `key_id = "key_front_door"` (igual ao `id` do `.tres`). O `success_message` que já existia no `EquipableAction` finalmente é exibido via `interact_label`.

> Nota de segurança: seu código atual faz `rigid_body_door.freeze = false` **antes** do `if rigid_body_door:` no ramo destrancado; se a porta não for `RigidBody3D` isso quebra. Mova o `freeze = false` para dentro do `if`.

> **Checkpoint da Parte 3.** (a) Pegar a Chave → Tab → focar o slot → **E** → "equipado" (veja `equipment.equipped` no debug label). (b) Ir até a porta trancada com a chave equipada → abre e a chave sai do inventário. (c) Sem chave → porta continua trancada. (d) RG → **E** abre o inspetor; **E** fecha. (e) Pilha com `battery` já em 100 → o item **não** é gasto.

---

## 4. Sistema de drop

Três peças, da menor para a maior. Todas dependem do **`ItemSpawner`**.

```
 ┌── Drop manual (tecla G) ──┐
 │                           ├──▶ ItemSpawner.spawn_item() ──▶ instancia o pickup no mundo
 └── Loot (LootDropper) ─────┘
		└─ LootTable ─ LootEntry ─ ItemData
```

### 4.1 `ItemSpawner` — o único lugar que cria itens no mundo

`Entities/Items/Loot/item_spawner.gd` 🆕

```gdscript
class_name ItemSpawner

## Cria o pickup do `item` em `where` (posição global) como filho de `parent`.
## `impulse` só tem efeito se o pickup tiver um RigidBody3D.
static func spawn_item(item: ItemData, where: Vector3, parent: Node, impulse := Vector3.ZERO) -> Node3D:
	if item == null or item.world_scene_path.is_empty():
		push_warning("ItemSpawner: item sem world_scene_path: %s" % (item.name if item else "null"))
		return null
	var scene := load(item.world_scene_path) as PackedScene
	if scene == null:
		push_warning("ItemSpawner: não carregou " + item.world_scene_path)
		return null

	var node := scene.instantiate() as Node3D
	parent.add_child(node)                # primeiro entra na árvore…
	node.global_position = where          # …depois posiciona (global_* exige estar na árvore)

	# O mundo manda o ItemData para o pickup (garante que é o MESMO recurso que saiu do inventário).
	var comp := _find_collectable(node)
	if comp:
		comp.item_data = item

	var body := _find_body(node)
	if body and impulse != Vector3.ZERO:
		body.apply_central_impulse(impulse)
	return node


static func _find_collectable(root: Node) -> CollectableInteraction:
	for n in root.find_children("InteractionComponent", "", true, false):
		if n is CollectableInteraction:
			return n
	return null


static func _find_body(root: Node) -> RigidBody3D:
	if root is RigidBody3D:
		return root
	var found := root.find_children("*", "RigidBody3D", true, false)
	return found[0] as RigidBody3D if found.size() > 0 else null
```

### 4.2 Drop manual (tecla **G**)

No `InventoryController`:

```gdscript
@export var drop_distance: float = 0.8
@export var drop_impulse: float = 2.0

func drop_slot(index: int) -> void:                    # 🆕
	if index < 0 or index >= inventory_slots.size():
		return
	var slot := inventory_slots[index]
	if not slot.slot_filled:
		return
	var item := slot.slot_data
	if not item.droppable or item.world_scene_path.is_empty():
		print("Este item não pode ser dropado: ", item.name)
		return

	var player := Global.player
	var cam := player.camera
	var forward := -cam.global_basis.z
	var pos := _drop_position(player, cam, forward)
	var impulse := forward * drop_impulse + Vector3.UP * 1.0

	remove_at(index)     # tira do inventário (e o EquipmentManager desequipa sozinho)
	ItemSpawner.spawn_item(item, pos, player.get_tree().current_scene, impulse)


# Não deixa o item nascer dentro de parede: se há algo entre a câmera e o ponto, para antes.
func _drop_position(player: Player, cam: Camera3D, forward: Vector3) -> Vector3:
	var from := cam.global_position
	var to := from + forward * drop_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)   # camada 1 = "wolrd"
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return (hit.position + hit.normal * 0.15) if not hit.is_empty() else to
```

E o `_unhandled_input` final (junta usar e dropar):

```gdscript
func _unhandled_input(event: InputEvent) -> void:      # ✏️
	if not inventory_canvas_layer.visible:
		return
	if inspector and inspector.is_open:
		return
	if event.is_action_pressed("use"):
		use_slot(get_focused_slot_index())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("drop"):
		drop_slot(get_focused_slot_index())
		get_viewport().set_input_as_handled()
```

Pontos que decidem se funciona:

- O pickup precisa estar na **camada 4** (`collision_layer = 8`), senão o `interactRay` (máscara 24) nunca mais enxerga o item dropado.
- O item dropado reaparece como coletável porque o spawner reinjeta o `item_data`.
- Dropar o item equipado desequipa (via `item_removed`).

### 4.3 Loot — tabela de drop reutilizável

`Entities/Items/Loot/loot_entry.gd` 🆕

```gdscript
extends Resource
class_name LootEntry

@export var item: ItemData
## Peso relativo no sorteio da `pool` (não é porcentagem). Ignorado nos `guaranteed`.
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export var min_quantity: int = 1
@export var max_quantity: int = 1
```

`Entities/Items/Loot/loot_table.gd` 🆕

```gdscript
extends Resource
class_name LootTable

## Sempre dropam.
@export var guaranteed: Array[LootEntry] = []
## Sorteio ponderado.
@export var pool: Array[LootEntry] = []
## Quantos sorteios fazer na pool.
@export var rolls: int = 1
## Chance (0..1) de CADA sorteio não render nada.
@export_range(0.0, 1.0, 0.01) var nothing_chance: float = 0.0
## false = cada entrada da pool só pode sair uma vez por drop.
@export var allow_duplicates: bool = true


func roll(rng: RandomNumberGenerator = null) -> Array[ItemData]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var result: Array[ItemData] = []
	for entry in guaranteed:
		_append(result, entry, rng)

	var available: Array = pool.duplicate()
	for i in rolls:
		if available.is_empty():
			break
		if rng.randf() < nothing_chance:
			continue
		var picked := _pick_weighted(available, rng)
		if picked == null:
			continue
		_append(result, picked, rng)
		if not allow_duplicates:
			available.erase(picked)
	return result


func _append(result: Array[ItemData], entry: LootEntry, rng: RandomNumberGenerator) -> void:
	if entry == null or entry.item == null:
		return
	var qty := rng.randi_range(entry.min_quantity, maxi(entry.min_quantity, entry.max_quantity))
	for i in qty:
		result.append(entry.item)


func _pick_weighted(entries: Array, rng: RandomNumberGenerator) -> LootEntry:
	var total := 0.0
	for e in entries:
		if e != null and e.item != null:
			total += maxf(e.weight, 0.0)
	if total <= 0.0:
		return null
	var r := rng.randf() * total
	for e in entries:
		if e == null or e.item == null:
			continue
		r -= maxf(e.weight, 0.0)
		if r <= 0.0:
			return e
	return null


## Ferramenta de balanceamento: imprime quantas vezes cada item saiu em `n` drops.
func debug_stats(n: int = 1000) -> void:
	var counts := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345                      # semente fixa = resultado reproduzível
	for i in n:
		for item in roll(rng):
			counts[item.id] = int(counts.get(item.id, 0)) + 1
	print("LootTable em %d drops: %s" % [n, counts])
```

`Entities/Items/Loot/loot_dropper.gd` 🆕 — nó que você pendura em qualquer coisa que "solta" itens:

```gdscript
extends Node
class_name LootDropper

@export var loot_table: LootTable
## De onde os itens saem. Vazio = posição do nó pai (precisa ser Node3D).
@export var spawn_point: Node3D
@export var scatter_radius: float = 0.4
@export var toss_impulse: float = 2.0


func drop() -> void:
	if loot_table == null:
		push_warning("LootDropper sem loot_table em " + str(get_path()))
		return
	var origin_node := spawn_point if spawn_point else get_parent() as Node3D
	if origin_node == null:
		return
	var scene_root := get_tree().current_scene
	for item in loot_table.roll():
		var offset := Vector3(
			randf_range(-scatter_radius, scatter_radius), 0.3,
			randf_range(-scatter_radius, scatter_radius))
		var impulse := Vector3(randf_range(-1.0, 1.0), toss_impulse, randf_range(-1.0, 1.0))
		ItemSpawner.spawn_item(item, origin_node.global_position + offset, scene_root, impulse)
```

Criação de uma tabela no editor: *FileSystem → botão direito em `Resources/Loot/` → New Resource → `LootTable`* → preencha `guaranteed`/`pool` com `LootEntry` (cada um apontando para um `.tres` de `Resources/Items/`).

### 4.4 Gatilho 1: container que o player abre (gaveta, baú)

Como o `InteractionController` fala com qualquer componente por *duck typing*, basta implementar os mesmos membros que ele usa (`hover_label`, `interact_label`, `can_interact`, `pre_interact()`, `interact()`, `post_interact()`):

`Interaction/InteractableScripts/container_interaction_component.gd` 🆕

```gdscript
extends Node
class_name ContainerInteraction

@export var loot_dropper: LootDropper
@export var hover_label: String = "Abrir"
@export var opened_label: String = "Vazio"
@export var one_shot: bool = true
@export var cooldown_s: float = 0.5        # só vale se one_shot = false

var interact_label: String = ""
var can_interact: bool = true
var is_interacting: bool = false
var _next_time_ms: int = 0

func pre_interact() -> void:
	is_interacting = true

func post_interact() -> void:
	is_interacting = false

func interact() -> void:
	if not can_interact or Time.get_ticks_msec() < _next_time_ms:
		return
	loot_dropper.drop()
	if one_shot:
		can_interact = false
		hover_label = opened_label
		interact_label = opened_label
	else:
		_next_time_ms = Time.get_ticks_msec() + int(cooldown_s * 1000.0)
```

Montagem na cena do baú:

```
Chest (StaticBody3D, collision_layer = 8)
├── MeshInstance3D, CollisionShape3D
├── InteractionComponent (script = ContainerInteraction)  ← nome exato; loot_dropper = ../LootDropper
└── LootDropper (loot_table = Resources/Loot/<tabela>.tres, spawn_point = um Marker3D acima do baú)
```

### 4.5 Gatilho 2: qualquer evento (morte, quebra, puzzle resolvido)

`LootDropper.drop()` é público. Ligue em qualquer sinal:

```gdscript
# exemplo: algo que "quebra"
signal broken
func _ready() -> void:
	broken.connect($LootDropper.drop)
```

### 4.6 Armadilhas (leia antes de debugar às 2 da manhã)

| Sintoma | Causa provável |
|---|---|
| Item dropado não pode ser pego de novo | Pickup fora da camada 4, ou `InteractionComponent` não é filho direto do corpo, ou nome diferente de `InteractionComponent`. |
| Item nasce dentro/atrás da parede | Use `_drop_position()` (4.2); em loot, ponha `spawn_point` num `Marker3D` livre. |
| `Another resource is loaded from path…` | Você usou `PackedScene` em `ItemData` apontando para uma cena que referencia o próprio `.tres` (2.2). Use `world_scene_path`. |
| `load()` devolve `null` | `world_scene_path` vazio ou você moveu a cena sem atualizar a string. |
| Item some no chão ao trocar de cena | Itens dropados são filhos de `current_scene`. Persistir exige um registro (Parte 6). |
| Dropou item e a mão continua com o modelo | `EquipmentManager` não está conectado a `item_removed` (veja o `await owner.ready` na 3.4). |
| Sorteio parece "viciado" | `weight` não é porcentagem. Rode `loot_table.debug_stats(1000)`. |

> **Checkpoint da Parte 4.** (a) Tab → focar Chave → **G** → a chave cai à frente, rola, e dá para pegá-la de novo. (b) Baú com tabela `guaranteed=[Pilha]` → abrir → 1 pilha salta. (c) `debug_stats(1000)` mostra proporções coerentes com os pesos. (d) Inventário cheio + coletar item solto → item permanece.

---

## 5. Ordem recomendada de implementação (checklist)

**Fundação (Parte 2)**
- [ ] `ItemData` com `id`, `world_scene_path`, `droppable`
- [ ] `ItemData` extraídos para `Resources/Items/*.tres`
- [ ] `InventorySlot.fill_slot()` completo + `clear_slot()`
- [ ] `InventoryController` com `pickup_item()→bool`, `remove_at`, `find_slot_by_id`, sinais
- [ ] Coleta corrigida (`reject_collect`, guard `in_inventory`, `owner.queue_free()`)
- [ ] `Player.inventory` / `Player.equipment`
- [ ] Ação de input `drop` (G)
- [ ] `item_pickup.tscn` padrão

**Itens (Parte 3)**
- [ ] `ItemActionContext` + `ActionData.execute()/consumes_item()`
- [ ] `InventoryController.use_slot()` + tecla E
- [ ] Consumível (+ `Player.apply_stat_modifier`)
- [ ] `EquipmentManager` + equipável
- [ ] `ItemInspector` + inspecionável
- [ ] Chave ↔ porta

**Drop (Parte 4)**
- [ ] `ItemSpawner`
- [ ] `drop_slot()` + tecla G
- [ ] `LootEntry` / `LootTable` / `LootDropper`
- [ ] `ContainerInteraction` + baú de teste

---

## 6. Depois disso (extensões naturais)

1. **Empilhamento:** `stackable`/`max_stack` já estão reservados. Separe "dado do item" (`ItemData`, imutável) de "item no slot" (`ItemStack { item: ItemData, quantity: int }`); o slot guarda um `ItemStack`. Isso também resolve o problema de mutar recurso compartilhado (1.4).
2. **Separar dados da UI:** mover o array de itens para um `Inventory` (Resource/RefCounted) e fazer a UI só *refletir* os sinais `inventory_changed`. Pré-requisito de qualquer save.
3. **Trocar slots (drag & drop):** `_get_drag_data` deve retornar um dicionário (`{from = inventory_slot_id}`), `_can_drop_data` validar e `_drop_data` emitir `ont_item_swapped` (renomeie o typo para `on_item_swapped`). Hoje o mouse está capturado; seria preciso liberar o cursor com a UI aberta.
4. **Save/Load:** serializar `[{id, quantity}]`; reconstruir via um catálogo `id → ItemData` (um `ItemDatabase` varrendo `Resources/Items/`). Itens no chão: guardar `{id, transform}`.
5. **Feedback:** marcador "E" no slot equipado (conectar `equipped_changed`), mensagem "Inventário cheio", som de coleta (o `await som_de_coleta.finished` comentado no controller já aponta a ideia) e a animação de voar até `InventoryTarget` (código comentado em `CollectableInteraction`).

---

## 7. Pendências antigas que encontrei (fora do inventário)

- `project.godot` aponta `config/icon="res://icon.svg"`, mas só existe `icon.png`.
- Três `.tres` (`Assets/Textures/Common/{snow,rock,rocky_terrain}`) e `Scenes/Testes/terrainy_demo.tscn` referenciam `res://addons/terrainy/...`, que **não está** no zip. Reinstale o addon ou apague esses recursos.
- `Lv_Note`, `Lv_IdentityCard`, `Lv_Lamp` estendem `Interactable`, que não existe (1.6).
- `.gitignore` só ignora `.godot/` e `/android/`. Sugestão: adicionar `*.tmp`, `*.blend1` e `_Archive/`.
- `_Archive/Zips/Godot_v3.6-stable_win64.exe.zip` tem 34 MB e não é do projeto — candidato a apagar.
- `Scenes/wolrd.gd` (typo de "world"; a camada física 1 também se chama `wolrd`). Renomear exige trocar também o nome da camada em *Project Settings → Layer Names*.
