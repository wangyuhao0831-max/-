extends Node
## Tavern：营业日生命周期管理器（autoload）—— 日循环与日级统计的权威。
## 生命周期：StartDay → OpenTavern → Service → CloseTavern → DaySummary → NextDay。
## 职责（单一）：
##   1) 按 GameClock 时间推进阶段（营业窗口数据驱动）；
##   2) 日级统计（顾客/完成/失败订单/收入/成本/利润）；
##   3) 声望数值（成功订单 +2 / 失败订单 -3，clamp 0..100）；
##   4) 生成 DaySummary 快照并触发自动存档请求（EventBus.save_requested）。
## 生成闸门：can_spawn_customer()（未营业 / 临近关门禁止）由 CustomerSpawner 查询。
## 注：无 class_name（autoload 名 = 全局访问符号）。

const PHASE_START_DAY := &"start_day"
const PHASE_OPEN_TAVERN := &"open_tavern"
const PHASE_SERVICE := &"service"
const PHASE_CLOSE_TAVERN := &"close_tavern"
const PHASE_DAY_SUMMARY := &"day_summary"
const PHASE_NEXT_DAY := &"next_day"

## 声望规则（成功/失败订单）。
const REP_SUCCESS := 2
const REP_FAIL := -3
const REP_MIN := 0
const REP_MAX := 100
const REP_START := 50

## 日期间距（游戏秒；测试/演示可调小，默认演示节奏）。
var prep_seconds: float = 5.0        # StartDay（打烊清理/开门准备）
var open_seconds: float = 7.0        # OpenTavern（开门迎客准备，尚不生成顾客）
var service_seconds: float = 90.0    # Service（营业中，生成顾客）
var summary_seconds: float = 8.0     # DaySummary（结算展示）
## 关门前停止接待新顾客的提前量（在 Service 末端）。
var closing_grace_seconds: float = 15.0

# --- 运行状态 ---
var day_index: int = 1
var phase: StringName = PHASE_START_DAY
var reputation: int = REP_START

# --- 日级统计（每天清零；结算用） ---
var customers_today: int = 0
var completed_orders_today: int = 0
var failed_orders_today: int = 0
var revenue_today: int = 0
var cost_today: int = 0
var profit_today: int = 0
var reputation_delta_today: int = 0
var gold_at_summary: int = 0

# --- 结算 ---
var last_summary: DaySummary = null

# 运行内部
var _open_orders := 0
var _customers_active := 0
var _summary_timer := 0.0
var _summary_entered := false
var _next_day_pending := false

# 解锁占位（Phase 2C 无实现；存档结构预留）
var unlocks: Dictionary = {}


func _ready() -> void:
	EventBus.order_created.connect(_on_order_created)
	EventBus.order_closed.connect(_on_order_closed)
	EventBus.order_failed.connect(_on_order_failed)
	EventBus.npc_entered.connect(_on_npc_entered)
	EventBus.npc_left.connect(_on_npc_left)
	print_debug("[DayManager] ready（Day 1 start_day）")


# --- 阶段 / 时间窗口（数据驱动） ---

func service_mark() -> float:
	return prep_seconds + open_seconds


func close_mark() -> float:
	return service_mark() + service_seconds


func _process(delta: float) -> void:
	if GameClock.is_paused:
		return
	match phase:
		PHASE_START_DAY, PHASE_OPEN_TAVERN, PHASE_SERVICE:
			_advance_pre_close()
		PHASE_CLOSE_TAVERN:
			_try_enter_summary()
		PHASE_DAY_SUMMARY:
			_summary_timer -= delta
			if _summary_timer <= 0.0:
				_to_next_day()
		PHASE_NEXT_DAY:
			_begin_new_day()


## 营业前/中阶段的按时间推进（含 Debug 快进跨窗口）。
func _advance_pre_close() -> void:
	var t := GameClock.current_day_seconds
	var target := PHASE_START_DAY
	if t >= service_mark():
		target = PHASE_SERVICE
	elif t >= prep_seconds:
		target = PHASE_OPEN_TAVERN
	if target == PHASE_SERVICE and t >= close_mark():
		target = PHASE_CLOSE_TAVERN
	_set_phase(target)


func _try_enter_summary() -> void:
	if _customers_active <= 0 and _open_orders <= 0 and not _summary_entered:
		_enter_summary()


func _enter_summary() -> void:
	_summary_entered = true
	gold_at_summary = GameState.get_balance(Transaction.TAVERN_TILL_ID)
	profit_today = revenue_today - cost_today
	last_summary = DaySummary.new()
	last_summary.day = day_index
	last_summary.customers = customers_today
	last_summary.completed_orders = completed_orders_today
	last_summary.failed_orders = failed_orders_today
	last_summary.revenue = revenue_today
	last_summary.cost = cost_today
	last_summary.profit = profit_today
	last_summary.reputation_change = reputation_delta_today
	last_summary.gold = gold_at_summary
	_set_phase(PHASE_DAY_SUMMARY)
	_summary_timer = summary_seconds
	EventBus.day_summary_ready.emit(last_summary)
	EventBus.save_requested.emit(&"day_summary")
	print_debug("[DayManager] %s" % last_summary.to_text())


## DaySummary 结束 → NextDay → 新一天 StartDay。
func _to_next_day() -> void:
	_next_day_pending = true
	_set_phase(PHASE_NEXT_DAY)
	_begin_new_day()


func _begin_new_day() -> void:
	_next_day_pending = false
	day_index += 1
	GameClock.reset_day_seconds()
	_reset_day_counters()
	_summary_entered = false
	_set_phase(PHASE_START_DAY)
	EventBus.day_started.emit(day_index)
	print_debug("[DayManager] Day %d 开始" % day_index)


func _reset_day_counters() -> void:
	customers_today = 0
	completed_orders_today = 0
	failed_orders_today = 0
	revenue_today = 0
	cost_today = 0
	profit_today = 0
	reputation_delta_today = 0
	_open_orders = 0
	_customers_active = 0
	gold_at_summary = 0
	last_summary = null


func _set_phase(new_phase: StringName) -> void:
	if phase == new_phase:
		return
	phase = new_phase
	EventBus.day_phase_changed.emit(phase)
	print_debug("[DayManager] phase -> %s" % phase)


# --- 对外查询 / 指令 ---

## 是否处于 Service 阶段（只在此阶段可生成顾客）。
func is_serving() -> bool:
	return phase == PHASE_SERVICE


## 当前是否允许生成新顾客：营业中且未到"关门前停止接待"窗口。
func can_spawn_customer() -> bool:
	if phase != PHASE_SERVICE:
		return false
	return GameClock.current_day_seconds < close_mark() - closing_grace_seconds


## 顾客是否已全部离场且无进行中订单（结算/重置闸门）。
func is_empty_of_customers() -> bool:
	return _customers_active <= 0 and _open_orders <= 0


## 手动提前关门（仅 Service 阶段有效）。
func request_close_tavern() -> bool:
	if phase != PHASE_SERVICE:
		return false
	_set_phase(PHASE_CLOSE_TAVERN)
	return true


## 调试/测试：直接跳到营业中（service 窗口起点）。
func debug_start_service() -> void:
	if GameClock.current_day_seconds < service_mark():
		GameClock.debug_advance_seconds(service_mark() - GameClock.current_day_seconds)
	_advance_pre_close()


## 调试/测试：重置"今天"（保持金币/声望/存档；要求无在场顾客）。
func request_reset_day() -> bool:
	if not is_empty_of_customers():
		return false
	GameClock.reset_day_seconds()
	_reset_day_counters()
	_summary_entered = false
	_set_phase(PHASE_START_DAY)
	EventBus.day_started.emit(day_index)
	return true


## 设置声望（存档载入/调试）；返回 clamp 后的值。
func set_reputation(value: int) -> int:
	reputation = clampi(value, REP_MIN, REP_MAX)
	EventBus.reputation_changed.emit(reputation)
	return reputation


func _apply_reputation_delta(delta: int) -> void:
	reputation_delta_today += delta
	reputation = clampi(reputation + delta, REP_MIN, REP_MAX)
	EventBus.reputation_changed.emit(reputation)


## 存档载入：还原日与状态（不重置实时统计/顾客）。
func apply_day_state(new_day: int) -> void:
	day_index = maxi(new_day, 1)
	_reset_day_counters()
	_summary_entered = false
	GameClock.reset_day_seconds()
	_set_phase(PHASE_START_DAY)


# --- 事件监听 ---

func _on_order_created(order: Order) -> void:
	_open_orders += 1


func _on_order_closed(order: Order) -> void:
	_open_orders = maxi(_open_orders - 1, 0)
	completed_orders_today += 1
	revenue_today += order.total_price
	var definition := DataRegistry.get_item(order.item_id)
	var unit_cost := definition.cost if definition != null else 0
	cost_today += unit_cost * order.amount
	profit_today = revenue_today - cost_today
	_apply_reputation_delta(REP_SUCCESS)


func _on_order_failed(_order: Order) -> void:
	_open_orders = maxi(_open_orders - 1, 0)
	failed_orders_today += 1
	_apply_reputation_delta(REP_FAIL)


func _on_npc_entered(_npc_id: StringName) -> void:
	_customers_active += 1
	customers_today += 1


func _on_npc_left(_npc_id: StringName) -> void:
	_customers_active = maxi(_customers_active - 1, 0)
