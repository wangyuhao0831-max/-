extends RefCounted
## 自动化验收测试（Phase 2C / Vertical Slice Stabilization）：
## 连续两个完整营业日（缩短计时 + 倍率快进）：
## Day1：开张 → 两名顾客依次进店 → 下单 → 玩家交付 → 付款 → 离开 → 关门 → 结算
##       （校验顾客/完成订单/收入 8+8/成本 3+3/利润 10/声望 50+4/金币 16）→ 自动存档 → 次日
## Day2：开张 → 一名顾客下单后玩家故意不交付 → 订单超时失败 → 声望 54-3 → 结算 → 存档 → Day3 开始
## 存档校验：game_version/current_day/gold/reputation/inventory/unlocks。
## 运行：Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --smoke-days

const ITEM_BOTTLE := &"item_bottle_ale"
const NPC_TOMMY := &"npc_tommy"
const NPC_GRIMBLE := &"npc_grimble"

var _fails: Array[String] = []
var _checked := 0


func run(driver: Node) -> void:
	var tree := driver.get_tree()
	print("[SMOKE2C] begin: two full business days")
	await tree.process_frame
	await tree.process_frame

	var root := tree.current_scene
	if root == null:
		_finish(tree, "current_scene is null")
		return

	# --- 环境准备：隔离旧存档、缩短一天、加速 ---
	SaveManager.clear_save()
	DayManager.prep_seconds = 1.5
	DayManager.open_seconds = 1.5
	DayManager.service_seconds = 14.0
	DayManager.summary_seconds = 1.0
	DayManager.closing_grace_seconds = 2.0
	GameClock.time_scale = 6.0
	var spawner := root.get_node_or_null("TavernZone/CustomerSpawner") as CustomerSpawner
	if spawner == null:
		_finish(tree, "CustomerSpawner 未找到")
		return
	spawner.auto_spawn = false
	var player := root.get_node_or_null("Player") as CharacterBody3D
	var player_inv := player.get_node_or_null("Inventory") as Inventory if player != null else null
	if player_inv == null:
		_finish(tree, "玩家/库存未找到")
		return

	_expect(DayManager.day_index == 1 and DayManager.phase == DayManager.PHASE_START_DAY,
			"初始应为 Day1 start_day")
	_expect(not DayManager.can_spawn_customer(), "未营业时禁止生成顾客")
	_expect(GameClock.time_scale == 6.0, "时间倍率应生效")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	# --- Day 1：开张 → 两名顾客 → 交付 → 打烊 → 结算 ---
	DayManager.debug_start_service()
	_expect(await _wait_phase(DayManager.PHASE_SERVICE, 120), "Day1 进入 Service")
	if not _fails.is_empty():
		_finish(tree, "")
		return
	_expect(DayManager.can_spawn_customer(), "Service 窗口内可生成顾客")

	var rep_start := DayManager.reputation
	await _run_customer_round(tree, root, spawner, player, player_inv, NPC_TOMMY, true)
	await _run_customer_round(tree, root, spawner, player, player_inv, NPC_GRIMBLE, true)
	# 越过关门线 → 无在场顾客后自动结算。
	GameClock.debug_advance_seconds(40.0)
	print("[SMOKE2C] step: 等待 Day1 结算")
	_expect(await _wait_phase(DayManager.PHASE_DAY_SUMMARY, 2400), "Day1 应到达 DaySummary")
	_expect(DayManager.last_summary != null and DayManager.last_summary.day == 1, "Day1 结算对象")
	_expect(DayManager.customers_today == 2 and DayManager.completed_orders_today == 2,
			"Day1：顾客 2 / 完成 2")
	_expect(DayManager.failed_orders_today == 0, "Day1：失败 0")
	_expect(DayManager.revenue_today == 16 and DayManager.cost_today == 6
			and DayManager.profit_today == 10, "Day1：收入 16 / 成本 6 / 利润 10")
	_expect(GameState.get_balance(Transaction.TAVERN_TILL_ID) == 16, "Day1：金币 16")
	_expect(DayManager.reputation == rep_start + 2 * 2, "Day1：声望 +4")
	_expect(DayManager.last_summary == null or DayManager.last_summary.reputation_change == 4,
			"Day1 结算声望变化 +4")
	# 自动存档（save_requested 由根控制器写入）：
	var save1 := SaveManager.load_file()
	_expect(not save1.is_empty(), "Day1 结算后应存在存档")
	_expect(int(save1.get("current_day", 0)) == 1, "存档 current_day == 1")
	_expect(int(save1.get("gold", -1)) == 16, "存档 gold == 16")
	_expect(int(save1.get("reputation", -1)) == rep_start + 4, "存档 reputation 同步")
	_expect(String(save1.get("game_version", "")) == GameManager.VERSION, "存档含 game_version")
	_expect(save1.has("unlocks") and save1.has("inventory"), "存档结构含 unlocks/inventory")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	# --- 次日（自动）：Day 2 开始 ---
	print("[SMOKE2C] step: 等待 Day2 开始")
	_expect(await _wait_phase(DayManager.PHASE_START_DAY, 900), "应自动进入 Day2 start_day")
	_expect(DayManager.day_index == 2, "day_index == 2")
	_expect(await _wait_phase(DayManager.PHASE_SERVICE, 300), "Day2 自动进入 Service")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	# --- Day 2：一名顾客，故意不交付 → 订单超时失败 ---
	DayManager.debug_start_service()
	await tree.physics_frame
	var rep_before_fail := DayManager.reputation
	await _run_customer_round(tree, root, spawner, player, player_inv, NPC_TOMMY, false)
	print("[SMOKE2C] step: 等待 Day2 结算")
	_expect(await _wait_phase(DayManager.PHASE_DAY_SUMMARY, 2400), "Day2 应到达 DaySummary")
	_expect(DayManager.failed_orders_today == 1, "Day2：失败订单 1")
	_expect(DayManager.completed_orders_today == 0, "Day2：完成 0")
	_expect(DayManager.reputation == rep_before_fail - 3, "Day2：声望 -3（失败订单）")
	_expect(DayManager.last_summary != null and DayManager.last_summary.reputation_change == -3,
			"Day2 结算声望变化 -3")
	# Day2 存档被覆盖：
	var save2 := SaveManager.load_file()
	_expect(int(save2.get("current_day", 0)) == 2, "Day2 存档 current_day == 2")
	_expect(int(save2.get("reputation", -1)) == rep_before_fail - 3, "Day2 存档声望同步")
	_expect(int(save2.get("gold", -1)) == 16, "Day2 无销售金币仍 16")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	# --- Day 3 开始（两日验收终点） ---
	print("[SMOKE2C] step: 等待 Day3 开始")
	_expect(await _wait_phase(DayManager.PHASE_START_DAY, 900), "应自动进入 Day3 start_day")
	_expect(DayManager.day_index == 3, "day_index == 3（两日完整运行）")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	print("[SMOKE2C] PASS: %d 项断言全过 —— 两个完整营业日（Day1 完成×2 + Day2 失败×1）" % _checked)
	print("[SMOKE2C] PASS: 开张闸门/顾客流/结算/声望 50→54→51/存档×2/自动次日 全部验证")
	await tree.process_frame
	await tree.process_frame
	tree.quit(0)


## 一轮顾客：生成 → 等 wait_drink → 按 serve 决定是否交付 → 等离场。
func _run_customer_round(tree: SceneTree, root: Node, spawner: CustomerSpawner,
		player: Node3D, player_inv: Inventory, npc_id: StringName, serve: bool) -> void:
	var npc := spawner.spawn_customer()
	if npc == null:
		_expect(false, "生成顾客失败（%s）" % npc_id)
		return
	_expect(npc.get_npc_id() == npc_id, "顾客身份应为 %s" % npc_id)
	if not await _wait_state(npc, NPCStateMachine.S_WAIT_DRINK, 2400):
		_expect(false, "%s 未到达 wait_drink" % npc_id)
		return
	if serve:
		# 玩家从吧台补货并交付（走真实 NpcDelivery 链路）。
		var def := DataRegistry.get_item(ITEM_BOTTLE)
		if def != null and player_inv.get_count(ITEM_BOTTLE) < 1:
			player_inv.add_item(def, 1)
		var delivery := npc.get_node_or_null("Interactable") as NpcDelivery
		if delivery == null:
			_expect(false, "%s 缺交付组件" % npc_id)
			return
		var result := delivery.interact(player)
		_expect(result.success, "%s 交付应成功" % npc_id)
	else:
		# 不交付：快进越过订单超时（ttl 40s 游戏时间）。
		GameClock.debug_advance_seconds(50.0)
	if not await _wait_state(npc, NPCStateMachine.S_LEAVE, 2400):
		_expect(false, "%s 未完成到 Leave" % npc_id)
		return
	# LEAVE 状态 = 开始走出；需等节点真正离场释放（门外出走 + queue_free）。
	print("[SMOKE2C] step: 等待 %s 离场" % npc_id)
	var settled := false
	for i in 900:
		if spawner.get_active_npc() == null:
			settled = true
			break
		await tree.physics_frame
	if not settled:
		_expect(false, "%s 未离场释放（spawner 仍占用）" % npc_id)
	await tree.physics_frame
	await tree.physics_frame


func _zone(root: Node) -> Node:
	return root.get_node_or_null("TavernZone")


func _wait_phase(phase: StringName, max_frames: int) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	for i in max_frames:
		if DayManager.phase == phase:
			return true
		await tree.physics_frame
	return false


func _wait_state(npc: NPCController, state: StringName, max_frames: int) -> bool:
	var tree := npc.get_tree()
	for i in max_frames:
		if not is_instance_valid(npc):
			return false
		if npc.get_current_state() == state:
			return true
		await tree.physics_frame
	return false


func _expect(cond: bool, label: String) -> void:
	_checked += 1
	if not cond:
		_fails.append(label)


func _finish(tree: SceneTree, _why: String) -> void:
	if _fails.is_empty():
		return
	for line in _fails:
		print("[SMOKE2C] FAIL: %s" % line)
		push_error("[SMOKE2C] FAIL: %s" % line)
	await tree.process_frame
	tree.quit(1)
