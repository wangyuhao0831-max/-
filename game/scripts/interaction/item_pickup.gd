class_name ItemPickup
extends Interactable
## Interaction：可拾取的世界物品。
## Phase 2A 契约：interact() 先过 RuleValidator.validate_pickup()，通过后才执行
## Inventory.add_item() 并广播 InteractionResult（EventBus）。
## 库存归属：actor 子树中的 Inventory 组件（仍兼容 Phase 1 约定），
## actor_id 通过 GameState 反查（Inventory → actor）获得。

const ACTION := &"pickup_item"

## 物品定义（数据驱动，来自 .tres）。
@export var item_definition: ItemDefinition = null
## 本次拾取数量。
@export var amount: int = 1


func _ready() -> void:
	prompt_verb = "拾取"
	if item_definition != null and prompt_noun.is_empty():
		prompt_noun = item_definition.display_name


func can_interact(actor: Node3D) -> bool:
	return item_definition != null and _find_inventory(actor) != null


func interact(actor: Node3D) -> InteractionResult:
	if item_definition == null:
		return _finish(InteractionResult.failed(
			InteractionResult.CODE_NOT_READY, ACTION, &"", &"",
			"ItemPickup(%s) 未配置 item_definition" % name
		))
	if actor == null:
		return _finish(InteractionResult.failed(
			InteractionResult.CODE_ACTOR_UNKNOWN, ACTION, &"", item_definition.item_id,
			"拾取缺少 actor"
		))
	var inventory := _find_inventory(actor)
	if inventory == null:
		return _finish(InteractionResult.failed(
			InteractionResult.CODE_INVENTORY_UNKNOWN, ACTION, &"", item_definition.item_id,
			"actor 子树中未找到 Inventory"
		))
	var actor_id := GameState.get_actor_id_for_inventory(inventory.inventory_id)
	if actor_id == &"":
		actor_id = actor.name
	# 统一闸门：校验通过才允许变更（R3）。
	var verdict := RuleValidator.validate_pickup(actor_id, item_definition.item_id, amount)
	if not verdict.success:
		return _finish(verdict)
	var added := inventory.add_item(item_definition, amount)
	if added == amount:
		print_debug("[ItemPickup] %s x%d -> %s" % [item_definition.item_id, amount, inventory.inventory_id])
		queue_free()
		return _finish(InteractionResult.ok(
			ACTION, actor_id, item_definition.item_id,
			"拾取 %s x%d" % [item_definition.display_name, amount],
			{"inventory_id": inventory.inventory_id, "amount": amount}
		))
	# 校验与实际执行不一致（防御）：理论上 validate 通过后 add 必全量成功。
	amount -= added
	return _finish(InteractionResult.failed(
		InteractionResult.CODE_STATE_MISMATCH, ACTION, actor_id, item_definition.item_id,
		"拾取部分完成（added=%d/%d）" % [added, amount + added]
	))


## 在 actor 子树中查找首个名为 Inventory 的节点（组件约定，Phase 1 兼容）。
func _find_inventory(actor: Node3D) -> Inventory:
	if actor == null:
		return null
	var node := actor.find_child("Inventory", true, false)
	return node as Inventory


## 统一出口：广播结果后返回（UI/日志订阅 EventBus.interaction_result）。
func _finish(result: InteractionResult) -> InteractionResult:
	EventBus.interaction_result.emit(result)
	return result
