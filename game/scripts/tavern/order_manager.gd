class_name OrderManager
extends Node
## Tavern：订单管理器（场景节点，订单权威注册处）。
## 下单流程（Godot 侧规则，Game Brain）：
##   1) RuleValidator.validate_npc_request（档案/物品/偏好/数量）—— R3 闸门
##   2) NPC 须已注册 actor；已有 OPEN 订单则拒绝（order_active）
##   3) 物品价格 × 数量 = total；NPC 钱包须足够（insufficient_funds）
## 之后：mark_delivered（交付完成）/ mark_paid（收款关闭），事件经 EventBus。

const ACTION_CREATE := &"order_create"

var _orders: Dictionary[StringName, Order] = {}
var _seq := 0


## 下单；成功返回 ok（payload: order_id）。
func create_order(npc_id: StringName, item_id: StringName, amount: int = 1) -> InteractionResult:
	# R3 闸门：NPC 请求合法性。
	var verdict := RuleValidator.validate_npc_request(npc_id, item_id, amount)
	if not verdict.success:
		return verdict
	if not GameState.has_actor(npc_id):
		return InteractionResult.failed(
			InteractionResult.CODE_ACTOR_UNKNOWN, ACTION_CREATE, &"", npc_id,
			"NPC 未注册：%s" % npc_id)
	if get_open_order_for_npc(npc_id) != null:
		return InteractionResult.failed(
			InteractionResult.CODE_ORDER_ACTIVE, ACTION_CREATE, npc_id, &"",
			"%s 已有进行中的订单" % npc_id)
	var definition := DataRegistry.get_item(item_id)
	var total := definition.price * amount
	if GameState.get_balance(npc_id) < total:
		return InteractionResult.failed(
			InteractionResult.CODE_INSUFFICIENT_FUNDS, ACTION_CREATE, npc_id, item_id,
			"%s 金币不足（need=%d, have=%d）" % [npc_id, total, GameState.get_balance(npc_id)],
			{"need": total, "have": GameState.get_balance(npc_id)})
	_seq += 1
	var order := Order.new()
	order.order_id = StringName("order_%s_%d" % [npc_id, _seq])
	order.npc_id = npc_id
	order.item_id = item_id
	order.amount = amount
	order.unit_price = definition.price
	order.total_price = total
	order.created_at_msec = Time.get_ticks_msec()
	_orders[order.order_id] = order
	EventBus.order_created.emit(order)
	print_debug("[OrderManager] %s" % order.to_text())
	return InteractionResult.ok(
		ACTION_CREATE, npc_id, item_id,
		"订单已创建：%s x%d（%d 金币）" % [definition.display_name, amount, total],
		{"order_id": order.order_id, "total_price": total})


## 订单查询（任何阶段）。
func get_order(order_id: StringName) -> Order:
	return _orders.get(order_id, null)


## 某 NPC 的 OPEN 订单；无返回 null。
func get_open_order_for_npc(npc_id: StringName) -> Order:
	for order in _orders.values():
		if order.npc_id == npc_id and order.phase == Order.Phase.OPEN:
			return order
	return null


func has_open_order(npc_id: StringName) -> bool:
	return get_open_order_for_npc(npc_id) != null


## 交付完成：OPEN → FULFILLED（由 NPCController.deliver_from 在物品转移成功后调用）。
func mark_delivered(order_id: StringName) -> InteractionResult:
	var order := get_order(order_id)
	if order == null:
		return InteractionResult.failed(
			InteractionResult.CODE_ORDER_NOT_FOUND, &"order_deliver", &"", order_id,
			"订单不存在：%s" % order_id)
	if order.phase != Order.Phase.OPEN:
		return InteractionResult.failed(
			InteractionResult.CODE_ORDER_NOT_OPEN, &"order_deliver", order.npc_id, order_id,
			"订单不在可交付阶段（%s）" % order.phase_text())
	order.phase = Order.Phase.FULFILLED
	EventBus.order_fulfilled.emit(order)
	print_debug("[OrderManager] %s 已交付" % order.to_text())
	return InteractionResult.ok(&"order_deliver", order.npc_id, order_id, "订单已交付",
			{"order_id": order.order_id})


## 收款关闭：FULFILLED → CLOSED（付款成功、交易记录后调用）。
func mark_paid(order_id: StringName) -> InteractionResult:
	var order := get_order(order_id)
	if order == null:
		return InteractionResult.failed(
			InteractionResult.CODE_ORDER_NOT_FOUND, &"order_paid", &"", order_id,
			"订单不存在：%s" % order_id)
	if order.phase != Order.Phase.FULFILLED:
		return InteractionResult.failed(
			InteractionResult.CODE_ORDER_NOT_OPEN, &"order_paid", order.npc_id, order_id,
			"订单未交付不可收款（%s）" % order.phase_text())
	order.phase = Order.Phase.CLOSED
	EventBus.order_closed.emit(order)
	print_debug("[OrderManager] %s 已收款关闭" % order.to_text())
	return InteractionResult.ok(&"order_paid", order.npc_id, order_id, "订单已收款",
			{"order_id": order.order_id})


## 全部订单快照（测试/调试/后续存档）。
func all_orders() -> Array[Order]:
	var out: Array[Order] = []
	for order in _orders.values():
		out.append(order)
	return out


## 进行中订单数（调试/测试）。
func open_order_count() -> int:
	var n := 0
	for order in _orders.values():
		if order.phase == Order.Phase.OPEN:
			n += 1
	return n
