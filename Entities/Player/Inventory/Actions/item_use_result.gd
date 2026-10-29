extends RefCounted
class_name ItemUseResult

## NOT_HANDLED: o alvo não trata esta interação; a interação antiga pode continuar.
## FAILED: o alvo reconheceu a tentativa, mas a recusou.
## SUCCESS: a tentativa foi validada e pode ser executada.
enum Status {
	NOT_HANDLED,
	FAILED,
	SUCCESS
}

enum Disposition {
	## Usa o comportamento padrão definido pelo ActionData do item.
	DEFAULT,
	KEEP,
	CONSUME,
	TRANSFER
}

var status: Status = Status.NOT_HANDLED
var message: String = ""
var animation_name: StringName = &""
var effect: Callable = Callable()
var disposition: Disposition = Disposition.DEFAULT
## Para Disposition.TRANSFER, este é o Marker3D/Node3D que receberá o item.
var transfer_target: Node3D


static func not_handled() -> ItemUseResult:
	return ItemUseResult.new()


static func failed(message_text: String = "") -> ItemUseResult:
	var result := ItemUseResult.new()
	result.status = Status.FAILED
	result.message = message_text
	return result


static func completed(
	effect_callback: Callable = Callable(),
	animation: StringName = &"",
	item_disposition: Disposition = Disposition.DEFAULT,
	destination: Node3D = null
) -> ItemUseResult:
	var result := ItemUseResult.new()
	result.status = Status.SUCCESS
	result.effect = effect_callback
	result.animation_name = animation
	result.disposition = item_disposition
	result.transfer_target = destination
	return result
