class_name NpcDelivery
extends Interactable
## Interaction：NPC 交付交互组件（NPC 根节点的固定子节点，名为 "Interactable"，
## InteractionManager 组件解析约定：命中 NPC 身体后查找该子节点）。
## 仅在 NPC 处于等待交付且有 OPEN 订单时可交互；执行委托 NPCController.deliver_from
## （内部经 RuleValidator.validate_deliver 后转移物品并标记订单）。

@export var npc_path: NodePath = ^".."

var _npc: NPCController = null


func _ready() -> void:
	_npc = get_node_or_null(npc_path) as NPCController
	if _npc == null:
		push_warning("NpcDelivery(%s): 未找到 NPCController" % name)
	prompt_verb = "交付"


func can_interact(_actor: Node3D) -> bool:
	return _npc != null and _npc.is_waiting_delivery()


func make_prompt() -> InteractionPrompt:
	var noun := ""
	if can_interact(null):
		noun = _npc.open_order_item_display()
	if noun.is_empty():
		noun = "酒水"
	return InteractionPrompt.new(interaction_id, prompt_verb, noun)


func interact(actor: Node3D) -> InteractionResult:
	if _npc == null:
		return InteractionResult.failed(
			InteractionResult.CODE_NOT_READY, &"deliver_item", &"", &"",
			"NpcDelivery 未绑定 NPC")
	return _npc.deliver_from(actor)
