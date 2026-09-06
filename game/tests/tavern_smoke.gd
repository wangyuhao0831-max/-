extends RefCounted
## 真实酒馆闭环烟测（--smoke-tavern）：
## 在 tavern.tscn（主场景）里验证核心顾客环在新布局（碰撞/路径）下可跑通：
## 开张 → 生成顾客 → 走到座位并下单（验证路径无阻）→ 玩家从吧台拾取酒瓶 →
## 交付 → 付款/饮用/离场 → 座位释放。
## 运行：Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --smoke-tavern

const ITEM_BOTTLE := &"item_bottle_ale"
const NPC_TOMMY := &"npc_tommy"

var _fails: Array[String] = []
var _checked := 0


func run(driver: Node) -> void:
	var tree := driver.get_tree()
	print("[SMOKE-T] begin: real-tavern customer loop")
	await tree.process_frame
	await tree.process_frame

	var root := tree.current_scene
	if root == null or root.get("name") != "Tavern":
		_finish(tree, "当前主场景不是 tavern.tscn")
		return
	DayManager.debug_start_service()
	await tree.physics_frame
	await tree.physics_frame
	if DayManager.phase != DayManager.PHASE_SERVICE:
		_finish(tree, "开张失败（phase=%s）" % DayManager.phase)
		return
	var spawner := root.get_node_or_null("TavernZone/CustomerSpawner") as CustomerSpawner
	if spawner == null:
		_finish(tree, "CustomerSpawner 未找到")
		return
	spawner.auto_spawn = false
	var player := root.get_node_or_null("Player") as CharacterBody3D
	var player_inv := player.get_node_or_null("Inventory") as Inventory if player != null else null
	if player_inv == null:
		_finish(tree, "玩家库存未找到")
		return

	# 从吧台拾取一瓶（复用 ItemPickup 链路）。
	var pickup := root.get_node_or_null("BottlePickupA") as ItemPickup
	if pickup == null:
		_finish(tree, "BottlePickupA 未找到")
		return
	var pick_result := pickup.interact(player)
	_expect(pick_result.success, "吧台酒瓶拾取应成功")
	_expect(player_inv.get_count(ITEM_BOTTLE) == 1, "拾取后库存应为 1")

	var npc := spawner.spawn_customer()
	if npc == null:
		_finish(tree, "生成顾客失败")
		return
	_expect(npc.get_npc_id() == NPC_TOMMY, "顾客身份应为 npc_tommy")
	var reached := await _wait_state(npc, NPCStateMachine.S_WAIT_DRINK, 2400)
	if not reached:
		_expect(false, "顾客未到达 wait_drink（当前 %s）" % npc.get_current_state())
	if not _fails.is_empty():
		_finish(tree, "")
		return
	var seat := npc.get_seat()
	_expect(seat != null, "顾客应占用一个座位")

	var delivery := npc.get_node_or_null("Interactable") as NpcDelivery
	if delivery == null:
		_finish(tree, "顾客缺交付组件")
		return
	var result := delivery.interact(player)
	_expect(result.success, "真实酒馆交付应成功")
	_expect(player_inv.get_count(ITEM_BOTTLE) == 0, "交付后玩家应无酒瓶")
	_expect(await _wait_state(npc, NPCStateMachine.S_LEAVE, 2400), "顾客应完成付款→饮用→离场")
	var gone := false
	for i in 900:
		if spawner.get_active_npc() == null:
			gone = true
			break
		await tree.physics_frame
	_expect(gone, "顾客应离场")
	_expect(seat == null or seat.is_free(), "座位应释放")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	print("[SMOKE-T] PASS: %d 项断言全过 —— 真实酒馆顾客闭环（开张/拾取/寻路/下单/交付/离场/座位释放）" % _checked)
	await tree.process_frame
	await tree.process_frame
	tree.quit(0)


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
		print("[SMOKE-T] FAIL: %s" % line)
		push_error("[SMOKE-T] FAIL: %s" % line)
	await tree.process_frame
	tree.quit(1)
