extends RefCounted
## 自动化验收测试（Phase 2B / Tavern Minimum Customer Loop）：
## 两个 NPC（npc_tommy / npc_grimble）依次进入酒馆，复用同一座位（SeatA），
## 各自完成完整两轮订单流程：进入→找座→走向→坐下→下单→等待→玩家交付
## （经 RuleValidator + InteractionResult）→付款（Transaction/台账）→饮用→离开→座位释放。
## 由 DebugHUD 在命令行带 --smoke-loop 时加载执行。
## 运行：Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --smoke-loop

const ITEM_BOTTLE := &"item_bottle_ale"
const ACTOR_PLAYER := &"player"
const NPC_TOMMY := &"npc_tommy"
const NPC_GRIMBLE := &"npc_grimble"
const TILL_ID := &"tavern_till"

var _fails: Array[String] = []
var _checked := 0
var _npc_left_ids: Array[StringName] = []
var _transactions: Array[Transaction] = []


func run(driver: Node) -> void:
	var tree := driver.get_tree()
	print("[SMOKE2B] begin: tavern minimum customer loop")
	await tree.process_frame
	await tree.process_frame

	var root := tree.current_scene
	if root == null:
		_finish(tree, "current_scene is null")
		return

	# 关闭自动生成（避免测试期间 spawner 自行接待干扰断言）。
	var spawner := root.get_node_or_null("TavernZone/CustomerSpawner") as CustomerSpawner
	if spawner == null:
		_finish(tree, "CustomerSpawner 未找到")
		return
	spawner.auto_spawn = false
	# Phase 2C：顾客生成受营业窗口管制 —— 先开张（跳到 Service）。
	DayManager.debug_start_service()
	await tree.physics_frame
	await tree.physics_frame
	if DayManager.phase != DayManager.PHASE_SERVICE:
		_finish(tree, "开张失败（phase=%s）" % DayManager.phase)
		return
	EventBus.npc_left.connect(
		func(npc_id: StringName) -> void:
			_npc_left_ids.append(npc_id)
	)
	EventBus.transaction_completed.connect(
		func(tx: Transaction) -> void:
			_transactions.append(tx)
	)

	var player := root.get_node_or_null("Player") as CharacterBody3D
	var player_inv := player.get_node_or_null("Inventory") as Inventory if player != null else null
	if player_inv == null:
		_finish(tree, "玩家/库存未找到")
		return

	# 玩家从吧台拾取酒瓶补充货源（复用 Phase 1 链路；两轮各需 1 瓶）。
	var pickups := root.get_node_or_null("Pickups") as Node3D
	if pickups == null:
		_finish(tree, "Pickups 未找到")
		return
	for child in pickups.get_children():
		var pickup := child as ItemPickup
		if pickup != null and pickup.item_definition != null \
				and pickup.item_definition.item_id == ITEM_BOTTLE:
			pickup.interact(player)
	await tree.process_frame
	_expect(player_inv.get_count(ITEM_BOTTLE) >= 2, "玩家应持有 >=2 瓶麦酒（供两轮交付）")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	# --- 第一轮：npc_tommy ---
	var npc1 := spawner.spawn_customer()
	if npc1 == null:
		_finish(tree, "第一轮生成失败")
		return
	_expect(npc1.get_npc_id() == NPC_TOMMY, "第一轮应为 npc_tommy")
	_expect(await _wait_state(npc1, NPCStateMachine.S_WAIT_DRINK, 3600),
			"npc_tommy 应到达 wait_drink（含 进入/找座/走向/坐下/下单）")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	var seat1 := npc1.get_seat()
	_expect(seat1 != null and seat1.is_reserved_by(NPC_TOMMY), "npc_tommy 应占用一个座位")
	_expect(GameState.get_balance(NPC_TOMMY) == 40, "npc_tommy 钱包应为初始 40")

	var deliver1 := npc1.get_node_or_null("Interactable") as NpcDelivery
	if deliver1 == null:
		_finish(tree, "npc_tommy 缺少交付组件")
		return
	var result1 := deliver1.interact(player)
	_expect(result1.success, "第一轮交付应成功：%s" % result1.to_text())
	_expect(player_inv.get_count(ITEM_BOTTLE) == 2, "交付后玩家库存应剩 2 瓶（3 拾 - 1 交付）")
	var npc_inv1 := npc1.get_node_or_null("Inventory") as Inventory
	_expect(npc_inv1 != null and npc_inv1.get_count(ITEM_BOTTLE) == 1, "NPC 应收到 1 瓶")
	_expect(await _wait_state(npc1, NPCStateMachine.S_LEAVE, 2400),
			"npc_tommy 应完成 付款→饮用→离开")
	_expect(await _wait_gone(NPC_TOMMY, 300), "npc_tommy 应离场释放节点")
	if not _fails.is_empty():
		_finish(tree, "")
		return
	_expect(_npc_left_ids.has(NPC_TOMMY), "应广播 npc_left(tommy)")
	_expect(seat1 == null or seat1.is_free(), "第一轮后座位应释放")
	_expect(not GameState.has_actor(NPC_TOMMY) and not GameState.has_inventory(&"npc_inv_npc_tommy"),
			"tommy actor/库存应注销")
	_expect(GameState.get_balance(TILL_ID) == 8, "酒馆钱箱应入账 8 金币")
	_expect(await _wait_state_order_closed(1, 120), "第一张订单应关闭")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	# --- 第二轮：npc_grimble（复用同一座位） ---
	var npc2 := spawner.spawn_customer()
	if npc2 == null:
		_finish(tree, "第二轮生成失败")
		return
	_expect(npc2.get_npc_id() == NPC_GRIMBLE, "第二轮应为 npc_grimble")
	_expect(await _wait_state(npc2, NPCStateMachine.S_WAIT_DRINK, 3600),
			"npc_grimble 应到达 wait_drink")
	if not _fails.is_empty():
		_finish(tree, "")
		return
	var seat2 := npc2.get_seat()
	_expect(seat2 == seat1 and seat2 != null and seat2.is_reserved_by(NPC_GRIMBLE),
			"npc_grimble 应复用 npc_tommy 用过的同一座位")
	var deliver2 := npc2.get_node_or_null("Interactable") as NpcDelivery
	if deliver2 == null:
		_finish(tree, "npc_grimble 缺少交付组件")
		return
	var result2 := deliver2.interact(player)
	_expect(result2.success, "第二轮交付应成功：%s" % result2.to_text())
	_expect(player_inv.get_count(ITEM_BOTTLE) == 1, "第二轮交付后玩家库存应剩 1 瓶")
	_expect(await _wait_state(npc2, NPCStateMachine.S_LEAVE, 2400),
			"npc_grimble 应完成 付款→饮用→离开")
	_expect(await _wait_gone(NPC_GRIMBLE, 300), "npc_grimble 应离场释放节点")
	_expect(seat2 == null or seat2.is_free(), "第二轮后座位应再次释放")
	_expect(GameState.get_balance(TILL_ID) == 16, "两轮后酒馆钱箱应入账 16 金币")
	_expect(_transactions.size() == 2, "应产生 2 笔交易")
	_expect(await _wait_state_order_closed(2, 120), "两张订单都应关闭")
	_expect(_npc_left_ids.size() == 2, "应广播两次 npc_left")
	# 状态机迁移表抽查
	_expect(NPCStateMachine.new().can_transition(NPCStateMachine.S_SIT, NPCStateMachine.S_ORDER)
			and NPCStateMachine.new().can_transition(NPCStateMachine.S_WAIT_DRINK, NPCStateMachine.S_PAY),
			"状态机合法迁移抽查")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	print("[SMOKE2B] PASS: %d 项断言全过 —— 两轮顾客环（tommy→grimble 复用同一座位）" % _checked)
	print("[SMOKE2B] PASS: 座位占用→释放→复用/库存转移/付款 8+8=16/交易×2/订单×2 全部验证")
	await tree.process_frame
	await tree.process_frame
	tree.quit(0)


## 等待 NPC 到达某状态；超时返回 false。
func _wait_state(npc: NPCController, state: StringName, max_frames: int) -> bool:
	var tree := npc.get_tree()
	for i in max_frames:
		if not is_instance_valid(npc):
			return false
		if npc.get_current_state() == state:
			return true
		await tree.physics_frame
	return false


## 等待 NPC 节点离场释放。
func _wait_gone(npc_id: StringName, max_frames: int) -> bool:
	var zone := _zone()
	for i in max_frames:
		var npc := _find_npc_in_zone(zone, npc_id)
		if npc == null:
			return true
		await npc.get_tree().physics_frame
	return false


func _find_npc_in_zone(zone: Node, npc_id: StringName) -> NPCController:
	if zone == null:
		return null
	for child in zone.get_children():
		if child is NPCController:
			var npc := child as NPCController
			if npc.get_npc_id() == npc_id:
				return npc
	return null


func _wait_state_order_closed(need_count: int, max_frames: int) -> bool:
	var zone := _zone()
	if zone == null:
		return false
	var manager := zone.get_node_or_null("OrderManager") as OrderManager
	if manager == null:
		return false
	for i in max_frames:
		var closed := 0
		for order in manager.all_orders():
			if order.phase == Order.Phase.CLOSED:
				closed += 1
		if closed >= need_count:
			return true
		await manager.get_tree().physics_frame
	return false


var _zone_cache: Node = null


func _zone() -> Node:
	if _zone_cache == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.current_scene != null:
			_zone_cache = tree.current_scene.get_node("TavernZone")
	return _zone_cache


func _expect(cond: bool, label: String) -> void:
	_checked += 1
	if not cond:
		_fails.append(label)


func _finish(tree: SceneTree, _why: String) -> void:
	if _fails.is_empty():
		return
	for line in _fails:
		print("[SMOKE2B] FAIL: %s" % line)
		push_error("[SMOKE2B] FAIL: %s" % line)
	await tree.process_frame
	tree.quit(1)
