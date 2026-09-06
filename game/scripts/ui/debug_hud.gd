class_name DebugHUD
extends CanvasLayer
## UI（调试）：DevPlayground 调试浮层。
## 规则 R8：只订阅 EventBus 信号并格式化显示，不含任何业务决策。
## 附带自动化测试入口（测试逻辑与产品代码隔离，runner 需被引用持有）：
##   --smoke          → game/tests/dev_playground_smoke.gd（Phase 1 回归）
##   --smoke-contract → game/tests/phase2a_contract_smoke.gd（Phase 2A 契约）
##   --smoke-loop     → game/tests/phase2b_loop_smoke.gd（Phase 2B 顾客环）

@export_group("Dependencies")
@export var player_path: NodePath = ^"../Player"
@export var label_path: NodePath = ^"DebugText"
@export var zone_path: NodePath = ^"../TavernZone"

const REFRESH_INTERVAL := 0.15
const SMOKE_ARG := "--smoke"
const CONTRACT_ARG := "--smoke-contract"
const LOOP_ARG := "--smoke-loop"
const DAYS_ARG := "--smoke-days"
const TAVERN_ARG := "--check-tavern"
const TAVERN_SMOKE_ARG := "--smoke-tavern"
const WALL_PROBE_ARG := "--probe-wall"
const SMOKE_SCRIPT := "res://game/tests/dev_playground_smoke.gd"
const CONTRACT_SCRIPT := "res://game/tests/phase2a_contract_smoke.gd"
const LOOP_SCRIPT := "res://game/tests/phase2b_loop_smoke.gd"
const DAYS_SCRIPT := "res://game/tests/phase2c_days_smoke.gd"
const TAVERN_SCRIPT := "res://game/tests/tavern_probe.gd"
const TAVERN_SMOKE_SCRIPT := "res://game/tests/tavern_smoke.gd"
const WALL_PROBE_SCRIPT := "res://game/tests/asset_probe.gd"

var _player: PlayerController = null
var _label: Label = null
var _zone: Node3D = null
var _seat_manager: SeatManager = null
var _order_manager: OrderManager = null
var _prompt: InteractionPrompt = null
var _inventory: Inventory = null
var _last_result: InteractionResult = null
var _last_summary: DaySummary = null
var _refresh_accum: float = 0.0
# 持有 runner 引用：RefCounted 协程 await 挂起期间必须保持存活，
# 否则离开启动函数作用域即被回收、测试静默中断（已踩坑，见 TASKS）。
var _smoke_runner: Object = null


func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerController
	_label = get_node_or_null(label_path) as Label
	_zone = get_node_or_null(zone_path) as Node3D
	if _zone != null:
		_seat_manager = _zone.get_node_or_null("SeatManager") as SeatManager
		_order_manager = _zone.get_node_or_null("OrderManager") as OrderManager
	EventBus.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.interaction_result.connect(_on_interaction_result)
	EventBus.day_summary_ready.connect(_on_day_summary_ready)
	var args := OS.get_cmdline_user_args()
	if args.has(SMOKE_ARG):
		call_deferred("_launch_smoke", SMOKE_SCRIPT)
	elif args.has(CONTRACT_ARG):
		call_deferred("_launch_smoke", CONTRACT_SCRIPT)
	elif args.has(LOOP_ARG):
		call_deferred("_launch_smoke", LOOP_SCRIPT)
	elif args.has(DAYS_ARG):
		call_deferred("_launch_smoke", DAYS_SCRIPT)
	elif args.has(TAVERN_ARG):
		call_deferred("_launch_smoke", TAVERN_SCRIPT)
	elif args.has(TAVERN_SMOKE_ARG):
		call_deferred("_launch_smoke", TAVERN_SMOKE_SCRIPT)
	elif args.has(WALL_PROBE_ARG):
		call_deferred("_launch_smoke", WALL_PROBE_SCRIPT)


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= REFRESH_INTERVAL:
		_refresh_accum = 0.0
		_refresh_text()


func _refresh_text() -> void:
	if _label == null:
		return
	var lines: Array[String] = []
	lines.append("Project Arcane Tavern — DevPlayground (debug)")
	lines.append("FPS: %d   阶段: %s" % [Engine.get_frames_per_second(), GameState.game_phase])
	lines.append("营业: Day %d [%s] t=%.0fs x%d%s" % [
		DayManager.day_index, DayManager.phase, GameClock.current_day_seconds,
		GameClock.time_scale, "（暂停）" if GameClock.is_paused else "",
	])
	var till := Transaction.TAVERN_TILL_ID
	lines.append("金币 %d | 声望 %d | 今日 收入%d/成本%d/利润%d | 顾客%d 完成%d 失败%d" % [
		GameState.get_balance(till), DayManager.reputation,
		DayManager.revenue_today, DayManager.cost_today, DayManager.profit_today,
		DayManager.customers_today, DayManager.completed_orders_today,
		DayManager.failed_orders_today,
	])
	if DayManager.phase == DayManager.PHASE_DAY_SUMMARY and _last_summary != null:
		lines.append("== 日结算: %s" % _last_summary.to_text())
	if _player != null:
		var pos := _player.global_position
		var speed := Vector3(_player.velocity.x, 0.0, _player.velocity.z).length()
		lines.append("玩家: (%.1f, %.1f, %.1f)  水平速度 %.1f" % [pos.x, pos.y, pos.z, speed])
	else:
		lines.append("玩家: 未找到")
	if _prompt != null:
		lines.append("[E] %s" % _prompt.to_text())
	else:
		lines.append("[E] —（无可交互目标）")
	if _last_result != null:
		lines.append("最近结果: %s" % _last_result.to_text())
	if _inventory != null:
		lines.append("库存 [%s]:" % _inventory.inventory_id)
		if _inventory.stack_count() == 0:
			lines.append("  （空）")
		else:
			for stack in _inventory.list_stacks():
				if stack.definition != null:
					lines.append("  %s x%d" % [stack.definition.display_name, stack.count])
	else:
		lines.append("库存: 未连接")
	lines.append("NPC / 座位 / 订单:")
	lines.append("  %s" % _state_overview_text())
	lines.append("")
	lines.append("WASD 移动 | 鼠标视角 | 左键捕获鼠标 | Esc 释放 | E 拾取/交付 | Q 丢下")
	_label.text = "\n".join(lines)


## NPC / Seat / Order 状态一览（只读格式化；调试用）。
func _state_overview_text() -> String:
	var parts: Array[String] = []
	if _zone == null:
		return "（TavernZone 未找到）"
	for child in _zone.get_children():
		if child is NPCController:
			var npc := child as NPCController
			var seat := npc.get_seat()
			parts.append("NPC %s: %s（座 %s）" % [
				npc.get_npc_id(), npc.get_current_state(),
				seat.seat_id if seat != null else "-",
			])
	if _seat_manager == null:
		return "; ".join(parts) if not parts.is_empty() else "（无 NPC）"
	parts.append("座位 空闲%d/%d" % [_seat_manager.free_seat_count(), _seat_manager.total_seats()])
	if _order_manager != null:
		var open_n := 0
		var closed_n := 0
		var failed_n := 0
		for order in _order_manager.all_orders():
			match order.phase:
				Order.Phase.OPEN:
					open_n += 1
				Order.Phase.CLOSED:
					closed_n += 1
				Order.Phase.FAILED:
					failed_n += 1
		parts.append("订单 open=%d closed=%d failed=%d" % [open_n, closed_n, failed_n])
	return "; ".join(parts)


func _on_prompt_changed(prompt: InteractionPrompt) -> void:
	_prompt = prompt


func _on_inventory_changed(inventory: Inventory) -> void:
	_inventory = inventory


func _on_interaction_result(result: InteractionResult) -> void:
	_last_result = result


func _on_day_summary_ready(summary: DaySummary) -> void:
	_last_summary = summary


func _launch_smoke(script_path: String) -> void:
	var script := load(script_path)
	if script == null:
		push_error("DebugHUD: 无法加载测试脚本 %s" % script_path)
		return
	_smoke_runner = script.new()
	# call() 绕开静态检查：runner 脚本无 class_name，基类 Object 无 run 成员。
	_smoke_runner.call("run", self)
