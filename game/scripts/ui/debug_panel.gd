class_name DebugPanel
extends CanvasLayer
## UI（调试）：Phase 2C 调试面板（按钮驱动，无业务逻辑 —— 只是把用户意图
## 转成对 DayManager / GameClock / Spawner / Inventory 的调用并显示反馈）。
## process_mode = ALWAYS：游戏暂停时面板仍可操作（恢复/倍率）。

const SPEED_STEPS: Array[float] = [1.0, 2.0, 4.0, 8.0]
const GOLD_STEP := 25
const TIME_STEP := 30.0

@export_group("Dependencies")
@export var spawner_path: NodePath = ^"../TavernZone/CustomerSpawner"
@export var inventory_path: NodePath = ^"../Player/Inventory"

var _spawner: CustomerSpawner = null
var _inventory: Inventory = null
var _status: Label = null
var _speed_index := 0
var _pause_button: Button = null
var _speed_button: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_spawner = get_node_or_null(spawner_path) as CustomerSpawner
	_inventory = get_node_or_null(inventory_path) as Inventory
	_build_panel()


func _build_panel() -> void:
	var box := VBoxContainer.new()
	box.name = "PanelBox"
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.offset_left = -288.0
	box.offset_top = 8.0
	box.offset_right = -8.0
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var title := Label.new()
	title.text = "Debug Panel"
	box.add_child(title)

	box.add_child(_make_button("▶ 开始营业（跳到 Service）", _on_open_service))
	box.add_child(_make_button("生成顾客", _on_spawn_customer))
	box.add_child(_make_button("添加物品（空酒瓶 x1）", _on_add_item))
	box.add_child(_make_button("添加金币 +%d" % GOLD_STEP, _on_add_gold))
	box.add_child(_make_button("时间快进 +%ds" % int(TIME_STEP), _on_advance_time))
	box.add_child(_make_button("提前关门", _on_close_tavern))
	box.add_child(_make_button("重置今天", _on_reset_day))
	_pause_button = _make_button("暂停", _on_toggle_pause)
	_speed_button = _make_button("倍率 x1", _on_cycle_speed)
	box.add_child(_pause_button)
	box.add_child(_speed_button)

	_status = Label.new()
	_status.text = ""
	_status.custom_minimum_size = Vector2(0.0, 40.0)
	box.add_child(_status)


func _make_button(text: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 30.0)
	button.pressed.connect(callable)
	return button


func _say(message: String) -> void:
	_status.text = message


# --- 动作（均返回可读反馈；守卫写在系统侧，这里只汇报） ---

func _on_open_service() -> void:
	DayManager.debug_start_service()
	_say("开始营业（phase=%s）" % DayManager.phase)


func _on_spawn_customer() -> void:
	if _spawner == null:
		_say("未找到 CustomerSpawner")
		return
	var npc := _spawner.spawn_customer()
	if npc != null:
		_say("已生成 %s" % npc.get_npc_id())
	else:
		_say("生成失败：phase=%s（需 Service 窗口内）" % DayManager.phase)


func _on_add_item() -> void:
	if _inventory == null:
		_say("未找到玩家库存")
		return
	var definition := DataRegistry.get_item(&"item_bottle_ale")
	if definition == null:
		_say("物品未注册：item_bottle_ale")
		return
	var added := _inventory.add_item(definition, 1)
	_say("添加物品：+%d（调试赠送，不记账成本）" % added)


func _on_add_gold() -> void:
	GameState.credit(Transaction.TAVERN_TILL_ID, GOLD_STEP)
	_say("金币 +%d（现 %d）" % [GOLD_STEP, GameState.get_balance(Transaction.TAVERN_TILL_ID)])


func _on_advance_time() -> void:
	GameClock.debug_advance_seconds(TIME_STEP)
	_say("时间快进 +%ds（day=%.0fs, phase=%s）" % [TIME_STEP, GameClock.current_day_seconds, DayManager.phase])


func _on_close_tavern() -> void:
	if DayManager.request_close_tavern():
		_say("已提前关门（等待在店顾客完成后结算）")
	else:
		_say("当前不可关门（phase=%s）" % DayManager.phase)


func _on_reset_day() -> void:
	if DayManager.request_reset_day():
		_say("已重置今天（Day %d，回到 start_day）" % DayManager.day_index)
	else:
		_say("重置失败：仍有顾客/订单在场")


func _on_toggle_pause() -> void:
	GameClock.set_paused(not GameClock.is_paused)
	_pause_button.text = "继续" if GameClock.is_paused else "暂停"
	_say("paused=%s" % GameClock.is_paused)


func _on_cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEED_STEPS.size()
	GameClock.time_scale = SPEED_STEPS[_speed_index]
	_speed_button.text = "倍率 x%d" % int(GameClock.time_scale)
	_say("time_scale x%d" % int(GameClock.time_scale))
