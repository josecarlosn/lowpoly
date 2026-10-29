# Guia inicial — Sistema de uso de itens

Projeto: **lowpoly** · Godot 4 · GDScript

Este sistema foi pensado para manter a lógica específica de cada item em seu próprio script, enquanto o controlador centraliza o fluxo comum: validar a tentativa, reproduzir uma animação opcional, aplicar o efeito e manter/consumir/transferir o item.

## 1. Responsabilidade de cada peça

- `ItemData`: definição do item — ID, nome, descrição, ícone, cena de mundo, cena da mão e configuração opcional de ação. Ao coletar, o inventário cria uma cópia de runtime independente para aquela unidade.
- `ActionData`: configuração opcional — animação padrão e política padrão após o sucesso. As subclasses atuais podem manter (`KEEP`) ou consumir (`CONSUME`); uma transferência é solicitada explicitamente pelo `ItemUseResult`.
- `EquippedItemBehavior`: classe-base para o script na raiz da cena equipada. Oferece `use_primary()`, `use_secondary()` e `reload()`.
- `ItemUseResult`: resultado de uma tentativa: não tratada, recusada ou bem-sucedida; pode fornecer uma função de efeito, animação, política de consumo e destino de transferência.
- `ItemActionController`: coordena a execução e bloqueia troca/drop de equipamento durante ações animadas.
- Componente interativo do mundo: decide se aceita o item. O item não precisa conhecer a porta, parafuso ou relógio.

`ActionData` **não** representa obrigatoriamente cada tecla ou subação, e o enum `ActionType` antigo não é o despachante das ações. Um revólver poderá implementar disparo e recarga no mesmo script, devolvendo animações diferentes em cada método. `ConsumableAction` e `EquipableAction` servem nesta etapa principalmente para configurar o resultado padrão do item, não para limitar o que ele pode fazer.

## 2. Fluxo de uso

### Uso próprio

1. O jogador clica sem estar mirando em um componente interativo.
2. `ItemActionController` chama `use_primary()` no `EquippedItemBehavior` do item equipado.
3. O item retorna um `ItemUseResult`.
4. O controlador reproduz a animação pedida, se houver, executa o efeito no marcador ou ao final da animação e processa o resultado.

A tecla **F** ficou mapeada para a ação genérica `secondary_use`. A tecla **R** foi adicionada como `reload`. Se o item não implementar o método correspondente, nada acontece.

### Uso contextual

1. O jogador equipa um item e clica em um alvo interativo.
2. Se o componente do alvo implementar `try_use_item(item_data, player, item_instance)`, o controlador pergunta ao alvo se ele trata aquela tentativa.
3. O alvo retorna `ItemUseResult.not_handled()` se não for uma ação dele, `ItemUseResult.failed(...)` se reconhecer mas recusar a tentativa, ou `ItemUseResult.completed(...)` se aceitar.
4. Em caso de sucesso, o controlador executa o efeito, reproduz a animação configurada e aplica a política final.

As interações antigas continuam como fallback para componentes que não implementam `try_use_item`.

## 3. Exemplo: item com múltiplas ações

Crie o script do comportamento como filho da classe-base:

```gdscript
extends EquippedItemBehavior
class_name RevolverBehavior

func on_equipped() -> void:
    # O script do modelo pode ser recriado ao desequipar/re-equipar.
    # O estado persistente fica na cópia runtime do ItemData.
    if not item_data.runtime_state.has("ammo"):
        item_data.runtime_state["ammo"] = 6

func use_primary() -> ItemUseResult:
    if int(item_data.runtime_state.get("ammo", 0)) <= 0:
        return ItemUseResult.failed("Sem munição.")

    return ItemUseResult.completed(
        Callable(self, "_fire"),
        &"Fire",
        ItemUseResult.Disposition.KEEP
    )

func reload() -> ItemUseResult:
    return ItemUseResult.completed(
        Callable(self, "_reload"),
        &"Reload",
        ItemUseResult.Disposition.KEEP
    )

func _fire() -> bool:
    var ammo := int(item_data.runtime_state.get("ammo", 0))
    if ammo <= 0:
        return false
    item_data.runtime_state["ammo"] = ammo - 1
    # Criar o disparo/raio/som aqui.
    return true

func _reload() -> bool:
    item_data.runtime_state["ammo"] = 6
    return true
```

Este é um **exemplo de integração**, não um script de arma já instalado no projeto. `Fire` e `Reload` precisam existir em um `AnimationPlayer` dentro da cena equipada. O comportamento e as animações continuam pertencendo ao revólver.

## 4. Sincronizar um efeito com o momento certo da animação

Por padrão, se a animação configurada existir, o efeito é aplicado ao final dela. Para disparar o efeito em um quadro específico:

1. A raiz do modelo equipado precisa estender `EquippedItemBehavior`.
2. Abra a animação no `AnimationPlayer` do modelo.
3. Adicione uma **Call Method Track** apontando para a raiz (`.`).
4. No instante correto, chame `notify_action_effect()`.

O controlador aplica o efeito uma única vez quando recebe esse marcador. Se não houver marcador, usa o fim da animação como fallback. As animações de ação devem ser não cíclicas.

O `animation_name` de `ItemUseResult` tem prioridade. Se ficar vazio, o controlador tenta o `animation_name` do `ActionData` do item. O caminho `animation_player_path` é opcional; se vazio, o controlador procura um nó chamado `AnimationPlayer` na cena equipada.

## 5. Exemplo: alvo que aceita um item específico

A porta deste projeto já implementa esse padrão usando `required_item_id`. O item de chave que veio no projeto tem `id = &"key_teste"`; para testar, configure `required_item_id = &"key_teste"` no componente da porta e marque `is_locked = true`.

```gdscript
func try_use_item(
    item_data: ItemData,
    player: Player,
    item_instance: Node3D
) -> ItemUseResult:
    if item_data.id != required_item_id:
        return ItemUseResult.failed("Isso não serve aqui.")

    return ItemUseResult.completed(
        Callable(self, "_apply_interaction").bind(player),
        &"",
        ItemUseResult.Disposition.DEFAULT
    )
```

Este snippet ilustra o contrato; a porta existente já possui uma implementação própria. Para um parafuso ou capô, o componente do alvo pode verificar o ID (ou outras condições) e devolver `KEEP`, para que a ferramenta permaneça no inventário.

## 6. Exemplo: transferir uma peça para um relógio

O componente do relógio pode devolver um resultado com `Disposition.TRANSFER` e `transfer_target` apontando para um `Marker3D` que representa o encaixe:

```gdscript
return ItemUseResult.completed(
    Callable(self, "_finish_installation").bind(item_data),
    &"",
    ItemUseResult.Disposition.TRANSFER,
    part_socket
)
```

O controlador move a instância equipada até o `part_socket`, alinha-a ao destino, chama o efeito de conclusão e remove a referência do inventário. Se a validação/efeito falhar, tenta restaurar o modelo à mão.

A animação de transferência usa `transfer_duration` e `transfer_arc_height` de `ActionData`. Para movimento muito específico ou animação do alvo, o próprio comportamento/componente poderá ser estendido sem reescrever o inventário.

## 7. Consumo

- `ConsumableAction` usa `CONSUME` por padrão após sucesso.
- `EquipableAction` usa `KEEP` por padrão; `one_time_use = true` faz o controlador consumir o item após sucesso contextual.
- Um `ItemUseResult` pode substituir a política padrão explicitamente por `KEEP`, `CONSUME` ou `TRANSFER`.
- Uma tentativa `FAILED` não consome item algum.

A chave atual foi configurada como `one_time_use = true`. A lanterna continua reutilizável. A luz do jogador agora começa apagada e só é alternada pelo comportamento da lanterna equipada.

## 8. Como adicionar um comportamento novo

1. Crie um script para a raiz da cena equipada, herdando de `EquippedItemBehavior`. A raiz da cena precisa ser `Node3D` (o `EquipmentController` já exige isso).
2. Implemente apenas os métodos relevantes: `use_primary()`, `use_secondary()`, `reload()` e/ou `on_equipped()`/`on_unequipped()`. Métodos que retornam `ItemUseResult.not_handled()` ficam inativos.
3. Em cada método, retorne `ItemUseResult.completed(...)` com o efeito e, quando necessário, o nome da animação. O resultado pode escolher `KEEP`, `CONSUME` ou `TRANSFER`; se usar `DEFAULT`, vale a política do `ActionData` do item.
4. Aponte `ItemData.hand_scene_path` para essa cena e `ItemData.world_scene_path` para a cena que representa o objeto no mundo.
5. Para estado que deve persistir ao desequipar — munição, durabilidade, interruptor etc. — use `item_data.runtime_state`, pois o nó da cena equipada é recriado quando o jogador equipa o item novamente.
6. Para uma interação contextual, implemente `try_use_item(item_data, player, item_instance)` no componente do alvo. O alvo valida as condições e retorna `ItemUseResult`; não faça a ferramenta conhecer todos os objetos do jogo.

## 9. Estado atual e limites desta etapa

Implementado nesta etapa:

- controlador central ligado ao Player;
- comportamento-base com uso primário, secundário e recarga;
- resultado de ação tipado;
- animação opcional com marcador de efeito;
- transferência genérica do modelo equipado para um `Node3D` receptor;
- consumo após sucesso;
- chave contextual para portas por `required_item_id`;
- lanterna usando o novo contrato;
- ação secundária no F e recarga no R.

Ainda não foram implementados os efeitos de bandagem, revólver, faca, pé de cabra, chave de fenda ou relógio. Não encontrei uma cena de bandagem no ZIP fornecido, e o projeto atual não tem um sistema de vida para aplicar cura nem as outras cenas/interações completas. Esses comportamentos devem ser adicionados incrementalmente sobre esta base.

**Estado individual por unidade:** cada coleta agora guarda uma cópia runtime de `ItemData`, com `runtime_state` independente. Um script de comportamento deve guardar nesse dicionário valores persistentes, como munição, carga ou durabilidade, em vez de confiar em variáveis locais do nó equipado (o nó é recriado ao re-equipar). A definição original embutida na cena não deve ser modificada em runtime. É uma ponte compatível com os slots atuais; se o projeto crescer bastante, poderá ser extraída para uma classe `ItemInstance` própria sem mudar o contrato de uso.
