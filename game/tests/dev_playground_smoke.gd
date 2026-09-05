extends RefCounted
## 自动化冒烟测试（Phase 1 / Goal 1）：
## 场景加载 → 直接驱动 ItemPickup.interact() → 断言 Inventory 更新、堆叠合并、
## EventBus.inventory_changed 事件链。
## 由 DebugHUD 在命令行带 --smoke 时加载执行（游戏内测试隔离）。
## 运行：Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --smoke

const EXPECTED_PICKUPS := 3
const ITEM_ID := &"item_bottle_ale"

# lambda 按值捕获局部变量；用成员变量做跨 lambda 计数（GDScript 4 语义）。
var _received := 0


func run(driver: Node) -> void:
	var tree := driver.get_tree()
	print("[SMOKE] begin: DevPlayground interaction chain")
	await tree.process_frame
	await tree.process_frame

	var root := tree.current_scene
	if root == null:
		_fail(tree, "current_scene is null（主场景未加载）")
		return

	var player := root.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		_fail(tree, "Player 未找到")
		return
	var inventory := player.get_node_or_null("Inventory") as Inventory
	if inventory == null:
		_fail(tree, "Player/Inventory 未找到")
		return

	# 预连接：统计 EventBus 广播次数（_received 为成员变量，见上）。
	EventBus.inventory_changed.connect(
		func(_inv: Inventory) -> void:
			_received += 1
	)

	if inventory.get_count(ITEM_ID) != 0:
		_fail(tree, "初始库存应为空（count=%d）" % inventory.get_count(ITEM_ID))
		return

	var pickups := root.get_node_or_null("Pickups") as Node3D
	if pickups == null or pickups.get_child_count() != EXPECTED_PICKUPS:
		_fail(tree, "Pickups 容器缺失或数量不符（got=%d）" % (0 if pickups == null else pickups.get_child_count()))
		return

	var picked := 0
	for child in pickups.get_children():
		var pickup := child as ItemPickup
		if pickup == null:
			continue
		pickup.interact(player)
		picked += 1
		await tree.process_frame

	if picked != EXPECTED_PICKUPS:
		_fail(tree, "可交互拾取物数量不符（picked=%d）" % picked)
		return
	if inventory.get_count(ITEM_ID) != EXPECTED_PICKUPS:
		_fail(tree, "库存数量不符（count=%d, expect=%d）" % [inventory.get_count(ITEM_ID), EXPECTED_PICKUPS])
		return
	if inventory.stack_count() != 1:
		_fail(tree, "同 ID 物品应合并为 1 个堆叠（stacks=%d）" % inventory.stack_count())
		return
	if _received < EXPECTED_PICKUPS:
		_fail(tree, "EventBus.inventory_changed 广播次数不足（got=%d, expect>=%d）" % [_received, EXPECTED_PICKUPS])
		return

	# --- 移动方向回归（曾出 bug：W/S 反转）---
	# 前提：出生朝向 = -Z（相机 yaw=0，未注入鼠标输入）。
	# W(前进) 应使 z 减小；S(后退) 应使 z 增大。
	# 注意：线性加速度 12 m/s² 下速度反转需 ~0.4s，按键窗口必须显著长于
	# 反转时间（45 物理帧 = 0.75s），否则惯性位移会掩盖真实方向。
	var spawn_z := player.global_position.z

	Input.action_press(&"move_forward")
	for i in 45:
		await tree.physics_frame
	Input.action_release(&"move_forward")
	var fwd_z := player.global_position.z
	if fwd_z > spawn_z - 0.5:
		_fail(tree, "W 方向错误：应前进(-Z) z=%.2f→%.2f 未前移" % [spawn_z, fwd_z])
		return

	var back_start := player.global_position.z
	Input.action_press(&"move_back")
	for i in 45:
		await tree.physics_frame
	Input.action_release(&"move_back")
	var back_z := player.global_position.z
	if back_z < back_start + 0.5:
		_fail(tree, "S 方向错误：应后退(+Z) z=%.2f→%.2f 未后移" % [back_start, back_z])
		return

	print("[SMOKE] PASS: 场景加载 OK; 拾取 x%d; 库存合并 1 堆叠; EventBus 广播 %d 次" % [picked, _received])
	print("[SMOKE] PASS: 移动方向 OK（W=-Z 前进 / S=+Z 后退，z: %.2f→%.2f→%.2f）" % [spawn_z, fwd_z, back_z])
	print("[SMOKE] PASS: 鼠标视角手感为手动验收项（headless 无法主观评估）")
	await tree.process_frame
	await tree.process_frame
	tree.quit(0)


func _fail(tree: SceneTree, why: String) -> void:
	print("[SMOKE] FAIL: %s" % why)
	push_error("[SMOKE] FAIL: %s" % why)
	await tree.process_frame
	tree.quit(1)
