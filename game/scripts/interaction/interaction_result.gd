class_name InteractionResult
extends RefCounted
## Interaction：统一交互结果类型（Phase 2A Core Contract）。
## 铁律：所有跨系统交互（AI/NPC/玩家触发）禁止用裸 bool 传递结果，
## 一律返回本类型：success + code + message + actor_id + target_id + action + payload。
## 本类同时承载全局结果码常量（单一来源，各系统引用）。

# --- 全局结果码（StringName） ---
const CODE_OK := &"ok"
const CODE_ACTOR_UNKNOWN := &"actor_unknown"
const CODE_TARGET_UNKNOWN := &"target_unknown"
const CODE_INVENTORY_UNKNOWN := &"inventory_unknown"
const CODE_ITEM_UNKNOWN := &"item_unknown"
const CODE_INVALID_AMOUNT := &"invalid_amount"
const CODE_INSUFFICIENT_ITEM := &"insufficient_item"
const CODE_INVENTORY_FULL := &"inventory_full"
const CODE_INVENTORY_EMPTY := &"inventory_empty"
const CODE_NPC_UNKNOWN := &"npc_unknown"
const CODE_ITEM_NOT_PREFERRED := &"item_not_preferred"
const CODE_ACTION_UNKNOWN := &"action_unknown"
## 对象未就绪（未配置定义/缺依赖等）。
const CODE_NOT_READY := &"not_ready"
## 校验通过后的实际执行与预期不一致（防御性错误）。
const CODE_STATE_MISMATCH := &"state_mismatch"
const CODE_NOT_IMPLEMENTED := &"not_implemented"
# --- Phase 2B：NPC / 订单 / 座位 / 经济 ---
## 金币不足（订单/付款前置）。
const CODE_INSUFFICIENT_FUNDS := &"insufficient_funds"
## NPC 已存在进行中的订单。
const CODE_ORDER_ACTIVE := &"order_active"
const CODE_ORDER_NOT_FOUND := &"order_not_found"
## 订单不在可操作阶段（未到交付/已处理）。
const CODE_ORDER_NOT_OPEN := &"order_not_open"
## 座位已被占用。
const CODE_SEAT_TAKEN := &"seat_taken"
## 无空闲座位。
const CODE_NO_SEAT := &"no_seat"
const CODE_SEAT_NOT_RESERVED := &"seat_not_reserved"

## 是否成功。
var success := false
## 结果码（CODE_* 常量）。
var code: StringName = CODE_OK
## 人类可读消息（调试/UI 用）。
var message: String = ""
## 行为发起者 ID（actor，如 &"player" / NPC id）。
var actor_id: StringName = &""
## 行为作用对象 ID（物品拾取=物品 id；交付/请求=NPC id；库存查询=inventory id）。
var target_id: StringName = &""
## 行为名（与 RuleValidator 的 action 同义，见 validate_action 路由）。
var action: StringName = &""
## 附加数据（成功时携带数量/库存等；失败时携带期望 vs 实际等）。
var payload: Dictionary = {}


func _init() -> void:
	# 仅允许通过 ok()/failed() 工厂构造，避免字段漏填。
	pass


## 构造成功结果。
static func ok(
	p_action: StringName, p_actor_id: StringName = &"", p_target_id: StringName = &"",
	p_message: String = "", p_payload: Dictionary = {}
) -> InteractionResult:
	var r := InteractionResult.new()
	r.success = true
	r.code = CODE_OK
	r.action = p_action
	r.actor_id = p_actor_id
	r.target_id = p_target_id
	r.message = p_message
	r.payload = p_payload
	return r


## 构造失败结果（code 必填）。
static func failed(
	p_code: StringName, p_action: StringName, p_actor_id: StringName = &"",
	p_target_id: StringName = &"", p_message: String = "", p_payload: Dictionary = {}
) -> InteractionResult:
	var r := InteractionResult.new()
	r.success = false
	r.code = p_code
	r.action = p_action
	r.actor_id = p_actor_id
	r.target_id = p_target_id
	r.message = p_message
	r.payload = p_payload
	return r


## 一行摘要（调试/UI 显示）。
func to_text() -> String:
	if not message.is_empty():
		return "[%s] %s" % [code, message]
	return "[%s] %s" % [code, action]
