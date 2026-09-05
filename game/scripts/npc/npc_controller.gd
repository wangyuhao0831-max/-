class_name NPCController
extends CharacterBody3D
## NPC：顾客控制器（Game Brain —— 规则与状态权威）。
## Phase 2B 最小顾客环：Enter → FindSeat → WalkToSeat → Sit → Order → WaitDrink
## →（玩家交付）→ Pay → Drink → Leave；座位由 SeatManager/TavernSeat 管理，
## 订单与收款经 RuleValidator / OrderManager / GameState 台账。
## AI 对接位置（预留，本阶段不实现）：下单选品 _pick_drink_item() 与对话等
## "决策点"即为后续 AI Brain 的建议注入位；AI 不参与当前任何决策。
##
## 使用约定：由 CustomerSpawner 实例化模板场景并调用 setup(profile, spawn_pos)
## 后再加入场景树（setup 需先于 Inventory._ready 配置唯一 inventory_id）。

const ARRIVE_DIST := 0.35
## 离店目标在门外侧的偏移（Z 轴，同 CustomerSpawner 出生偏移，形成"走出门外"）。
const EXIT_OFFSET := 1.2

@export var profile: NPCProfile = null

@export_group("Movement")
@export var walk_speed: float = 2.6

@export_group("Durations")
@export var sit_duration: float = 0.6
@export var drink_duration: float = 3.0
## 找座/下单失败时的重试间隔。
@export var retry_interval: float = 1.0

@export_group("Dependencies")
@export var door_path: NodePath = ^"../Door"
@export var seat_manager_path: NodePath = ^"../SeatManager"
@export var order_manager_path: NodePath = ^"../OrderManager"

var _machine: NPCStateMachine = null
var _runtime: NPCRuntimeState = null
var _seat_manager: SeatManager = null
var _order_manager: OrderManager = null
var _door: Node3D = null
var _inventory: Inventory = null

var _move_target: Vector3 = Vector3.ZERO
var _exit_target: Vector3 = Vector3.ZERO
var _last_walk_target: Vector3 = Vector3.ZERO
var _state_timer := 0.0
var _retry_timer := 0.0
var _order_attempted := false
var _pay_done := false
var _drink_consumed := false
var _leaving := false
var _arrived := false


## 实例化后、加入场景树前调用：绑定档案与出生点（配置子 Inventory 唯一 id）。
func setup(p_profile: NPCProfile, spawn_position: Vector3) -> void:
	profile = p_profile
	_runtime = NPCRuntimeState.new()
	_runtime.npc_id = p_profile.npc_id if p_profile != null else &""
	_runtime.profile = p_profile
	_runtime.spawn_position = spawn_position
	_runtime.entered_at_msec = Time.get_ticks_msec()
	if profile != null:
		var inv := get_node_or_null("Inventory") as Inventory
		if inv != null:
			inv.inventory_id = StringName("npc_inv_%s" % String(profile.npc_id))
		_apply_body_tint()


func _ready() -> void:
	if profile == null:
		push_error("NPCController(%s): setup() 未调用或档案缺失，禁用" % name)
		set_physics_process(false)
		return
	_door = get_node_or_null(door_path) as Node3D
	_seat_manager = get_node_or_null(seat_manager_path) as SeatManager
	_order_manager = get_node_or_null(order_manager_path) as OrderManager
	_inventory = get_node_or_null("Inventory") as Inventory
	if _seat_manager == null:
		push_warning("NPCController(%s): 未找到 SeatManager" % profile.npc_id)
	if _order_manager == null:
		push_warning("NPCController(%s): 未找到 OrderManager" % profile.npc_id)
	if _inventory == null:
		push_warning("NPCController(%s): 未找到 Inventory" % profile.npc_id)
	_machine = NPCStateMachine.new()
	_machine.setup(NPCStateMachine.S_ENTER_TAVERN)
	GameState.register_actor(profile.npc_id, _inventory.inventory_id if _inventory != null else &"")
	GameState.register_wallet(profile.npc_id, profile.wallet_coins)
	if _door != null:
		_exit_target = _door.global_position + Vector3(0.0, 0.0, -EXIT_OFFSET)
		_exit_target.y = global_position.y


func _exit_tree() -> void:
	if profile == null:
		return
	# 防御：任何原因离场都释放座位/注册（幂等）。
	var seat := _runtime.seat if _runtime != null else null
	if seat != null and seat.is_reserved_by(profile.npc_id):
		seat.release()
	GameState.unregister_actor(profile.npc_id)
	GameState.remove_wallet(profile.npc_id)


# --- 公开查询（交付交互 / 测试 / HUD） ---

func get_npc_id() -> StringName:
	return profile.npc_id if profile != null else &""


func get_current_state() -> StringName:
	return _machine.current_state() if _machine != null else &""


func get_order_id() -> StringName:
	return _runtime.order_id if _runtime != null else &""


## 当前进行中订单（无则 null）。
func get_open_order() -> Order:
	if _order_manager == null:
		return null
	return _order_manager.get_open_order_for_npc(get_npc_id())


func get_seat() -> TavernSeat:
	return _runtime.seat if _runtime != null else null


## 是否处于等待交付且存在未完成订单（NpcDelivery 提示闸门）。
func is_waiting_delivery() -> bool:
	return get_current_state() == NPCStateMachine.S_WAIT_DRINK and get_open_order() != null


## 等待交付订单的物品展示名（提示用；无返回 ""）。
func open_order_item_display() -> String:
	var order := get_open_order()
	if order == null:
		return ""
	var def := DataRegistry.get_item(order.item_id)
	return def.display_name if def != null else String(order.item_id)


## 玩家交付：校验（RuleValidator.validate_deliver）→ 转移物品 → 订单标记交付。
## actor 为交付发起者（通常玩家根节点，携带 Inventory 组件）。
func deliver_from(actor: Node3D) -> InteractionResult:
	const action := &"deliver_item"
	if not is_waiting_delivery():
		return _finish(InteractionResult.failed(
			InteractionResult.CODE_ORDER_NOT_OPEN, action, get_npc_id(), &"",
			"订单未就绪（NPC 不在等待交付）"
		))
	if actor == null:
		return _finish(InteractionResult.failed(
			InteractionResult.CODE_ACTOR_UNKNOWN, action, &"", get_npc_id(), "缺少交付者"
		))
	var giver_inventory := actor.find_child("Inventory", true, false) as Inventory
	if giver_inventory == null:
		return _finish(InteractionResult.failed(
			InteractionResult.CODE_INVENTORY_UNKNOWN, action, &"", get_npc_id(),
			"交付者无 Inventory"
		))
	var giver_id := GameState.get_actor_id_for_inventory(giver_inventory.inventory_id)
	if giver_id == &"":
		giver_id = actor.name
	var order := get_open_order()
	var definition := DataRegistry.get_item(order.item_id)
	# 统一闸门：交付规则（双方库存可用性 + 容量）。
	var verdict := RuleValidator.validate_deliver(giver_id, get_npc_id(), order.item_id, order.amount)
	if not verdict.success:
		return _finish(verdict)
	if giver_inventory.remove_item(order.item_id, order.amount) != order.amount:
		return _finish(InteractionResult.failed(
			InteractionResult.CODE_STATE_MISMATCH, action, giver_id, get_npc_id(),
			"交付扣减失败"
		))
	if _inventory == null or _inventory.add_item(definition, order.amount) != order.amount:
		# 防御回滚：归还交付者。
		giver_inventory.add_item(definition, order.amount)
		return _finish(InteractionResult.failed(
			InteractionResult.CODE_STATE_MISMATCH, action, giver_id, get_npc_id(),
			"NPC 收货失败（已回滚）"
		))
	var marked := _order_manager.mark_delivered(order.order_id)
	if not marked.success:
		return _finish(marked)
	print_debug("[NPC] %s 收到 %s x%d" % [get_npc_id(), order.item_id, order.amount])
	return _finish(InteractionResult.ok(
		action, giver_id, get_npc_id(),
		"交付 %s x%d" % [definition.display_name if definition != null else order.item_id, order.amount],
		{"order_id": order.order_id, "amount": order.amount}
	))


# --- 状态机驱动（Game Brain；AI 预留位见 _pick_drink_item） ---

func _physics_process(delta: float) -> void:
	if _machine == null:
		return
	if _state_timer > 0.0:
		_state_timer -= delta
	if _retry_timer > 0.0:
		_retry_timer -= delta
	var state := _machine.current_state()
	match state:
		NPCStateMachine.S_ENTER_TAVERN:
			if _walk_to(_door.global_position if _door != null else global_position, delta):
				_change_to(NPCStateMachine.S_FIND_SEAT)
		NPCStateMachine.S_FIND_SEAT:
			var seat := _seat_manager.find_free_seat() if _seat_manager != null else null
			if seat == null:
				if _retry_timer <= 0.0:
					_retry_timer = retry_interval
					print_debug("[NPC] %s 找座中…" % get_npc_id())
			elif seat.reserve(get_npc_id()):
				_runtime.seat = seat
				_move_target = seat.park_position()
				_move_target.y = global_position.y
				_change_to(NPCStateMachine.S_WALK_TO_SEAT)
		NPCStateMachine.S_WALK_TO_SEAT:
			if _walk_to(_move_target, delta):
				_change_to(NPCStateMachine.S_SIT)
		NPCStateMachine.S_SIT:
			if _state_timer <= 0.0:
				_change_to(NPCStateMachine.S_ORDER)
		NPCStateMachine.S_ORDER:
			if not _order_attempted and _retry_timer <= 0.0:
				_try_create_order()
		NPCStateMachine.S_WAIT_DRINK:
			# 注意：必须按 order_id 全阶段查询（get_open_order 只含 OPEN，
			# 交付后订单为 FULFILLED，用它会永远等不到）。
			var order := _order_manager.get_order(_runtime.order_id) if _order_manager != null else null
			if order != null:
				if order.phase == Order.Phase.FULFILLED:
					_change_to(NPCStateMachine.S_PAY)
				elif order.phase == Order.Phase.FAILED:
					_change_to(NPCStateMachine.S_LEAVE)
				elif order.phase == Order.Phase.OPEN \
						and GameClock.current_day_seconds >= order.expires_at_seconds:
					# Phase 2C：交付超时 → 订单失败 → 顾客放弃离开。
					print_debug("[NPC] %s 等待超时，放弃订单 %s" % [get_npc_id(), order.order_id])
					_order_manager.mark_failed(order.order_id)
					_change_to(NPCStateMachine.S_LEAVE)
		NPCStateMachine.S_PAY:
			if not _pay_done:
				_pay_done = true
				_do_pay()
				_change_to(NPCStateMachine.S_DRINK)
		NPCStateMachine.S_DRINK:
			if not _drink_consumed:
				_drink_consumed = true
				_consume_drink()
			if _state_timer <= 0.0:
				_change_to(NPCStateMachine.S_LEAVE)
		NPCStateMachine.S_LEAVE:
			if _walk_to(_exit_target, delta):
				_finish_leave()


## 统一迁移出口：状态切换 + EventBus 广播。
func _change_to(to_state: StringName) -> void:
	if _machine == null:
		return
	var previous := _machine.current_state()
	if _machine.transition_to(to_state):
		_state_timer = _timer_for(to_state)
		_retry_timer = 0.0
		EventBus.npc_state_changed.emit(get_npc_id(), previous, to_state)


func _timer_for(state: StringName) -> float:
	match state:
		NPCStateMachine.S_SIT:
			return sit_duration
		NPCStateMachine.S_DRINK:
			return drink_duration
	return 0.0


## 朝水平目标移动；返回是否到达。速度可调 + 重力落地。
func _walk_to(target: Vector3, delta: float) -> bool:
	# 目标变化时复位到达标记（否则会沿用上个目标的"已到达"）。
	if target.distance_to(_last_walk_target) > 0.01:
		_last_walk_target = target
		_arrived = false
	if _arrived:
		return true
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() <= ARRIVE_DIST:
		velocity.x = 0.0
		velocity.z = 0.0
		_arrived = true
		return true
	_arrived = false
	var dir := to_target.normalized()
	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	return false


## 决策点（AI 预留位）：从偏好中选第一个可负担（钱包>=总价）且已注册的物品；
## 无偏好命中则全物品表兜底。当前为确定性 Godot 规则 —— AI 接入后此处仅替换"建议"。
func _pick_drink_item() -> StringName:
	var balance := GameState.get_balance(get_npc_id())
	var candidates: Array[StringName] = []
	if profile != null:
		candidates.append_array(profile.preferred_item_ids)
	if candidates.is_empty():
		for id in DataRegistry.list_ids(DataRegistry.CATEGORY_ITEM):
			candidates.append(id)
	for id in candidates:
		var def := DataRegistry.get_item(id)
		if def != null and def.price > 0 and def.price <= balance:
			return id
	return &""


func _try_create_order() -> void:
	if _order_manager == null:
		return
	_order_attempted = true
	var item_id := _pick_drink_item()
	if item_id == &"":
		print_debug("[NPC] %s 无可负担饮品，稍后重试" % get_npc_id())
		_order_attempted = false
		_retry_timer = retry_interval
		return
	var result := _order_manager.create_order(get_npc_id(), item_id, 1)
	if result.success:
		var order := _order_manager.get_open_order_for_npc(get_npc_id())
		_runtime.order_id = order.order_id if order != null else &""
		_change_to(NPCStateMachine.S_WAIT_DRINK)
	else:
		print_debug("[NPC] %s 下单失败：%s" % [get_npc_id(), result.to_text()])
		_order_attempted = false
		_retry_timer = retry_interval


## 付款：钱包出账 → 酒馆入账 → 交易事件 → 订单关闭。
func _do_pay() -> void:
	var order := _order_manager.get_order(_runtime.order_id) if _order_manager != null else null
	if order == null:
		push_error("NPCController(%s): 付款时订单丢失" % get_npc_id())
		return
	if not GameState.debit(get_npc_id(), order.total_price):
		push_error("NPCController(%s): 付款失败（余额不足，order=%s）" % [get_npc_id(), order.order_id])
		return
	GameState.credit(Transaction.TAVERN_TILL_ID, order.total_price)
	var tx := Transaction.new()
	tx.transaction_id = StringName("tx_%s_%d" % [get_npc_id(), Time.get_ticks_msec()])
	tx.from_actor_id = get_npc_id()
	tx.to_actor_id = Transaction.TAVERN_TILL_ID
	tx.item_id = order.item_id
	tx.amount_coins = order.total_price
	tx.order_id = order.order_id
	tx.executed_at_msec = Time.get_ticks_msec()
	EventBus.transaction_completed.emit(tx)
	var closed := _order_manager.mark_paid(order.order_id)
	if not closed.success:
		push_warning("NPCController(%s): 订单关闭失败 %s" % [get_npc_id(), closed.to_text()])
	print_debug("[NPC] %s 付款 %d 金币（%s）" % [get_npc_id(), order.total_price, order.order_id])


## 喝酒：消耗已交付饮品。
func _consume_drink() -> void:
	var order := _order_manager.get_order(_runtime.order_id) if _order_manager != null else null
	if order == null:
		return
	if _inventory != null:
		_inventory.remove_item(order.item_id, order.amount)
	print_debug("[NPC] %s 饮用 %s x%d" % [get_npc_id(), order.item_id, order.amount])


func _finish_leave() -> void:
	if _leaving:
		return
	_leaving = true
	var seat := _runtime.seat
	if seat != null:
		seat.release()
		_runtime.seat = null
	EventBus.npc_left.emit(get_npc_id())
	print_debug("[NPC] %s 离店，座位释放" % get_npc_id())
	queue_free()


## 出生/展示：按档案染色（灰盒视觉）。
func _apply_body_tint() -> void:
	var body := get_node_or_null("BodyMesh") as MeshInstance3D
	if body == null or profile == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = profile.body_tint
	mat.roughness = 0.6
	body.material_override = mat


## 统一出口：广播结果后返回（与拾取/放下一致）。
func _finish(result: InteractionResult) -> InteractionResult:
	EventBus.interaction_result.emit(result)
	return result
