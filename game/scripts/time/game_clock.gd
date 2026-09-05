extends Node
## Time：游戏时钟（autoload）—— 时间权威。
## 职责：时间倍率（Engine.time_scale）、暂停/恢复（SceneTree.paused）、
## 当前营业日已流逝秒数（current_day_seconds，供营业窗口/订单超时等计时）。
## 语义：被缩放/暂停后，所有以 delta 驱动的游戏逻辑（NPC 移动/计时/生成）
## 自动同步 —— 本类只做统一源与调试快进，不重复实现节拍。
## 注：无 class_name（autoload 名 = 全局访问符号；Godot 4.7 规则）。

const MIN_SCALE := 0.1
const MAX_SCALE := 10.0

## 时间倍率（1.0 = 实时；>1 快进）。
var time_scale: float = 1.0:
	set(value):
		time_scale = clampf(value, MIN_SCALE, MAX_SCALE)
		Engine.time_scale = time_scale

## 是否暂停（由本类统一控制 SceneTree.paused）。
var is_paused: bool = false

## 当前营业日内已流逝秒数（倍率已折算；跨日由 DayManager 清零）。
var current_day_seconds: float = 0.0

## 历史累计游戏秒（跨日累计，测试/统计用）。
var total_game_seconds: float = 0.0


func _ready() -> void:
	# 暂停时本类仍需响应恢复请求（调试面板/键盘），挂 ALWAYS。
	process_mode = Node.PROCESS_MODE_ALWAYS
	time_scale = 1.0
	is_paused = false
	print_debug("[GameClock] ready")


func _process(delta: float) -> void:
	if is_paused:
		return
	# Engine.time_scale 已折算进 delta。
	current_day_seconds += delta
	total_game_seconds += delta


## 暂停游戏世界（true=暂停）。UI 侧（DebugPanel）为 ALWAYS，不受影响。
func set_paused(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused
	print_debug("[GameClock] paused=%s" % paused)


## 调试/脚本快进：直接推进当日时间（触发营业窗口判定/订单超时等）。
func debug_advance_seconds(seconds: float) -> void:
	current_day_seconds += maxf(seconds, 0.0)
	print_debug("[GameClock] advance +%s -> %.1f" % [seconds, current_day_seconds])


## 新的一天开始：清零当日秒数。
func reset_day_seconds() -> void:
	current_day_seconds = 0.0
