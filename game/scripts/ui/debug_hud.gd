class_name DebugHUD
extends CanvasLayer
## UI（调试）：DevPlayground 调试浮层。
## 规则 R8：只订阅 EventBus 信号并格式化显示，不含任何业务决策。
## 附带自动化测试入口（测试逻辑与产品代码隔离，runner 需被引用持有）：
##   --smoke            → game/tests/dev_playground_smoke.gd（Phase 1 回归）
##   --smoke-contract   → game/tests/phase2a_contract_smoke.gd（Phase 2A 契约）

@export_group("Dependencies")
@export var player_path: NodePath = ^"../Player"
@export var label_path: NodePath = ^"DebugText"

const REFRESH_INTERVAL := 0.15
const SMOKE_ARG := "--smoke"
const CONTRACT_ARG := "--smoke-contract"
const SMOKE_SCRIPT := "res://game/tests/dev_playground_smoke.gd"
const CONTRACT_SCRIPT := "res://game/tests/phase2a_contract_smoke.gd"

var _player: PlayerController = null
var _label: Label = null
var _prompt: InteractionPrompt = null
var _inventory: Inventory = null
var _last_result: InteractionResult = null
var _refresh_accum: float = 0.0
# 持有 runner 引用：RefCounted 协程 await 挂起期间必须保持存活，
# 否则离开启动函数作用域即被回收、测试静默中断（已踩坑，见 TASKS）。
var _smoke_runner: Object = null


func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerController
	_label = get_node_or_null(label_path) as Label
	EventBus.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.interaction_result.connect(_on_interaction_result)
	var args := OS.get_cmdline_user_args()
	if args.has(SMOKE_ARG):
		call_deferred("_launch_smoke", SMOKE_SCRIPT)
	elif args.has(CONTRACT_ARG):
		call_deferred("_launch_smoke", CONTRACT_SCRIPT)


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
	lines.append("")
	lines.append("WASD 移动 | 鼠标视角 | 左键捕获鼠标 | Esc 释放 | E 拾取 | Q 丢下")
	_label.text = "\n".join(lines)


func _on_prompt_changed(prompt: InteractionPrompt) -> void:
	_prompt = prompt


func _on_inventory_changed(inventory: Inventory) -> void:
	_inventory = inventory


func _on_interaction_result(result: InteractionResult) -> void:
	_last_result = result


func _launch_smoke(script_path: String) -> void:
	var script := load(script_path)
	if script == null:
		push_error("DebugHUD: 无法加载测试脚本 %s" % script_path)
		return
	_smoke_runner = script.new()
	# call() 绕开静态检查：runner 脚本无 class_name，基类 Object 无 run 成员。
	_smoke_runner.call("run", self)
