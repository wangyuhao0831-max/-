extends RefCounted
## 自动化契约测试（Phase 2A / Core Contract Layer）：
## GameState 注册/阶段、DataRegistry 扫描/查询/预留类别、InteractionResult 结构、
## RuleValidator 四条规则（pickup/deliver/npc_request/inventory availability）+ 统一路由。
## 由 DebugHUD 在命令行带 --smoke-contract 时加载执行。
## 运行：Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --smoke-contract

const ITEM_BOTTLE := &"item_bottle_ale"
const ITEM_MUG := &"item_wooden_mug"
const ITEM_UNKNOWN := &"item_zzz_none"
const NPC_TOMMY := &"npc_tommy"
const ACTOR_PLAYER := &"player"
const INV_PLAYER := &"player_inventory"
const ACTOR_BAR := &"test_npc_barkeep"
const INV_BAR := &"test_bar_stock"

var _fails: Array[String] = []
var _checked := 0


func run(driver: Node) -> void:
	var tree := driver.get_tree()
	print("[SMOKE2A] begin: Core Contract Layer")
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame

	var root := tree.current_scene
	if root == null:
		_finish(tree, "current_scene is null")
		return
	var player := root.get_node_or_null("Player") as CharacterBody3D
	var inventory := player.get_node_or_null("Inventory") as Inventory if player != null else null

	# --- 1) GameState：阶段 + Inventory/actor 注册 ---
	_expect(GameState.game_phase == &"playing", "阶段应为 playing（boot 后由 GameManager 驱动）")
	_expect(GameState.has_inventory(INV_PLAYER), "player_inventory 应已注册")
	_expect(GameState.has_actor(ACTOR_PLAYER), "player actor 应已注册")
	_expect(GameState.get_actor_id_for_inventory(INV_PLAYER) == ACTOR_PLAYER,
			"Inventory->actor 反查应命中 player")
	_expect(GameState.get_inventory_for_actor(ACTOR_PLAYER) == inventory,
			"actor->Inventory 解析应命中场景 Inventory")
	_expect(inventory != null and inventory.get_count(ITEM_BOTTLE) == 0,
			"初始库存应为空")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	# --- 2) DataRegistry：boot scan / 强类型查询 / 预留类别扩展 ---
	_expect(DataRegistry.has_item(ITEM_BOTTLE), "酒瓶应注册（items 目录扫描）")
	_expect(DataRegistry.has_item(ITEM_MUG), "木杯应注册")
	_expect(DataRegistry.count(DataRegistry.CATEGORY_ITEM) >= 2, "物品注册数 >= 2")
	_expect(not DataRegistry.has_item(ITEM_UNKNOWN), "未知物品不应命中")
	_expect(DataRegistry.get_item(ITEM_UNKNOWN) == null, "未知物品查询应为 null")
	_expect(DataRegistry.has_npc_profile(NPC_TOMMY), "汤米档案应注册（npcs 目录扫描）")
	var profile := DataRegistry.get_npc_profile(NPC_TOMMY)
	_expect(profile != null and not profile.display_name.is_empty(), "档案展示名非空")
	_expect(profile != null and profile.prefers(ITEM_BOTTLE), "汤米应偏好酒瓶")
	_expect(profile == null or not profile.prefers(ITEM_MUG), "汤米不应偏好木杯")
	# 预留类别（recipe/quest）走通用注册接口即可扩展：
	var probe := Resource.new()
	probe.resource_name = "recipe_probe"
	_expect(DataRegistry.register_resource(DataRegistry.CATEGORY_RECIPE, &"recipe_probe", probe),
			"recipe 预留类别可注册")
	_expect(DataRegistry.get_resource(DataRegistry.CATEGORY_RECIPE, &"recipe_probe") == probe,
			"recipe 预留类别可查询")
	_expect(DataRegistry.list_ids(DataRegistry.CATEGORY_RECIPE).has(&"recipe_probe"),
			"recipe list_ids 命中")
	DataRegistry.unregister_resource(DataRegistry.CATEGORY_RECIPE, &"recipe_probe")
	_expect(DataRegistry.count(DataRegistry.CATEGORY_RECIPE) == 0, "recipe 注销成功")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	# --- 3) InteractionResult：结构与工厂 ---
	var ok_result := InteractionResult.ok(&"unit_test", &"alice", &"bob", "你好", {"n": 1})
	_expect(ok_result.success and ok_result.code == InteractionResult.CODE_OK,
			"ok() 工厂：success/code")
	_expect(ok_result.action == &"unit_test" and ok_result.actor_id == &"alice"
			and ok_result.target_id == &"bob", "ok() 工厂：action/actor/target")
	_expect(int(ok_result.payload.get("n", 0)) == 1 and ok_result.to_text().contains("你好"),
			"ok() 工厂：payload/to_text")
	var fail_result := InteractionResult.failed(
		InteractionResult.CODE_INSUFFICIENT_ITEM, &"unit_test", &"alice", &"bob", "不足")
	_expect(not fail_result.success and fail_result.code == InteractionResult.CODE_INSUFFICIENT_ITEM,
			"failed() 工厂：success/code")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	# --- 4) RuleValidator：inventory availability / pickup / npc_request ---
	_expect(RuleValidator.validate_inventory_has(INV_PLAYER, ITEM_BOTTLE, 1).code
			== InteractionResult.CODE_INSUFFICIENT_ITEM, "空库存 has(1) -> insufficient_item")
	_expect(RuleValidator.validate_inventory_has(&"no_such_inv", ITEM_BOTTLE, 1).code
			== InteractionResult.CODE_INVENTORY_UNKNOWN, "未知库存 -> inventory_unknown")
	_expect(RuleValidator.validate_inventory_has(INV_PLAYER, ITEM_BOTTLE, 0).code
			== InteractionResult.CODE_INVALID_AMOUNT, "数量 0 -> invalid_amount")
	_expect(RuleValidator.validate_inventory_has(INV_PLAYER, ITEM_UNKNOWN, 1).code
			== InteractionResult.CODE_ITEM_UNKNOWN, "未知物品 -> item_unknown")
	_expect(RuleValidator.validate_pickup(ACTOR_PLAYER, ITEM_BOTTLE, 1).success,
			"pickup(1) 空库存但容量足 -> 允许")
	_expect(RuleValidator.validate_pickup(&"ghost_actor", ITEM_BOTTLE, 1).code
			== InteractionResult.CODE_ACTOR_UNKNOWN, "pickup 未知 actor -> actor_unknown")
	_expect(RuleValidator.validate_pickup(ACTOR_PLAYER, ITEM_UNKNOWN, 1).code
			== InteractionResult.CODE_ITEM_UNKNOWN, "pickup 未知物品 -> item_unknown")
	_expect(RuleValidator.validate_pickup(ACTOR_PLAYER, ITEM_BOTTLE, 0).code
			== InteractionResult.CODE_INVALID_AMOUNT, "pickup 数量 0 -> invalid_amount")
	_expect(RuleValidator.validate_npc_request(NPC_TOMMY, ITEM_BOTTLE, 1).success,
			"npc_request 偏好物品 -> 允许")
	_expect(RuleValidator.validate_npc_request(NPC_TOMMY, ITEM_MUG, 1).code
			== InteractionResult.CODE_ITEM_NOT_PREFERRED, "npc_request 非偏好 -> item_not_preferred")
	_expect(RuleValidator.validate_npc_request(&"npc_ghost", ITEM_BOTTLE, 1).code
			== InteractionResult.CODE_NPC_UNKNOWN, "npc_request 未知 NPC -> npc_unknown")
	# 统一路由 validate_action：
	var routed := RuleValidator.validate_action(&"pickup_item",
			{"actor_id": ACTOR_PLAYER, "item_id": ITEM_BOTTLE, "amount": 1})
	_expect(routed.success and routed.action == &"pickup_item", "validate_action 路由 pickup_item")
	_expect(RuleValidator.validate_action(&"npc_request_item",
			{"target_id": NPC_TOMMY, "item_id": ITEM_BOTTLE, "amount": 1}).success,
			"validate_action 路由 npc_request_item（npc 经 target_id）")
	_expect(RuleValidator.validate_action(&"no_such_action", {}).code
			== InteractionResult.CODE_ACTION_UNKNOWN, "未知 action -> action_unknown")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	# --- 5) 容量侧 + deliver 规则（把玩家库存塞满 64 堆叠） ---
	var definition := DataRegistry.get_item(ITEM_BOTTLE)
	_expect(definition != null, "酒瓶定义可获取")
	if definition == null or inventory == null:
		_finish(tree, "前置资源缺失")
		return
	var added := inventory.add_item(definition, 64 * 99)
	_expect(added == 64 * 99 and inventory.stack_count() == 64, "塞满 64 堆叠")
	_expect(RuleValidator.validate_inventory_can_receive(INV_PLAYER, ITEM_BOTTLE, 1).code
			== InteractionResult.CODE_INVENTORY_FULL, "满库存 can_receive -> inventory_full")
	_expect(RuleValidator.validate_pickup(ACTOR_PLAYER, ITEM_BOTTLE, 1).code
			== InteractionResult.CODE_INVENTORY_FULL, "满库存 pickup -> inventory_full")

	# 临时接收者（挂在场景根，_ready 自动注册；测试结束销毁验证注销）。
	var receiver := Inventory.new()
	receiver.name = "ContractTestStorage"
	receiver.inventory_id = INV_BAR
	(root as Node).add_child(receiver)
	await tree.process_frame
	_expect(GameState.has_inventory(INV_BAR), "临时接收库存已注册")
	GameState.register_actor(ACTOR_BAR, INV_BAR)
	_expect(GameState.has_actor(ACTOR_BAR), "临时接收 actor 已注册")
	_expect(RuleValidator.validate_deliver(ACTOR_PLAYER, &"npc_ghost", ITEM_BOTTLE, 1).code
			== InteractionResult.CODE_TARGET_UNKNOWN, "deliver 未知接收者 -> target_unknown")
	_expect(RuleValidator.validate_deliver(&"ghost_giver", ACTOR_BAR, ITEM_BOTTLE, 1).code
			== InteractionResult.CODE_ACTOR_UNKNOWN, "deliver 未知交付者 -> actor_unknown")
	_expect(RuleValidator.validate_deliver(ACTOR_PLAYER, ACTOR_BAR, ITEM_BOTTLE, 99999).code
			== InteractionResult.CODE_INSUFFICIENT_ITEM, "deliver 超出持有 -> insufficient_item")
	var deliver_ok := RuleValidator.validate_deliver(ACTOR_PLAYER, ACTOR_BAR, ITEM_BOTTLE, 2)
	_expect(deliver_ok.success, "deliver(2) 合法 -> 允许")
	# 接收容量分支：交付者持有充足（6336 >= 1），但接收库存被木杯塞满（无空槽）→ inventory_full。
	var mug_def := DataRegistry.get_item(ITEM_MUG)
	if mug_def != null:
		var fill := receiver.add_item(mug_def, 64 * 99)
		_expect(fill == 64 * 99, "接收库存塞满木杯 64 堆叠")
	_expect(RuleValidator.validate_deliver(ACTOR_PLAYER, ACTOR_BAR, ITEM_BOTTLE, 1).code
			== InteractionResult.CODE_INVENTORY_FULL, "deliver 接收者满 -> inventory_full")
	receiver.queue_free()
	await tree.process_frame
	await tree.process_frame
	_expect(not GameState.has_inventory(INV_BAR), "接收库存退出树后自动注销")
	_expect(not GameState.has_actor(ACTOR_BAR), "接收 actor 注销后不可查")
	if not _fails.is_empty():
		_finish(tree, "")
		return

	print("[SMOKE2A] PASS: %d 项断言全过（GameState/DataRegistry/InteractionResult/RuleValidator 4 规则+路由）" % _checked)
	print("[SMOKE2A] PASS: 注册→查询→注销生命周期 OK；Phase 1 场景加载无回归")
	await tree.process_frame
	await tree.process_frame
	tree.quit(0)


func _expect(cond: bool, label: String) -> void:
	_checked += 1
	if not cond:
		_fails.append(label)


func _finish(tree: SceneTree, _why: String) -> void:
	if _fails.is_empty():
		return
	for line in _fails:
		print("[SMOKE2A] FAIL: %s" % line)
		push_error("[SMOKE2A] FAIL: %s" % line)
	await tree.process_frame
	tree.quit(1)
