extends Node
## Core：全局启动编排与生命周期（autoload）。
## 职责单一：启动引导 + 基础运行信息；不含任何玩法业务逻辑（R7：无 God Object）。
## 依赖顺序见 docs/ARCHITECTURE.md §5：EventBus 先于 GameManager 注册。
## 注：无 class_name —— 以 autoload 名 GameManager 作为全局访问符号。

const VERSION := "0.1.0-dev"

## 自动测试场景：主场景可以是真实酒馆（tavern.tscn），但自动化回归依赖
## dev_playground 的节点布局 —— 检测到测试参数时自动切回（与主场景设置解耦）。
const TEST_SCENE := "res://game/scenes/dev/dev_playground.tscn"
const TEST_ARGS: Array[String] = ["--smoke", "--smoke-contract", "--smoke-loop", "--smoke-days"]


func _ready() -> void:
	print_debug("[GameManager] boot v%s (debug=%s)" % [VERSION, OS.is_debug_build()])
	if _has_test_arg():
		call_deferred("_reroute_to_test_scene")
	# 延迟一帧广播：保证场景树 ready 完成后订阅方才收到 game_booted。
	call_deferred("_emit_boot")


## 请求干净退出游戏（供 UI / 调试入口调用）。
func quit_game() -> void:
	get_tree().quit(0)


func _emit_boot() -> void:
	GameState.begin_playing()
	EventBus.game_booted.emit(Time.get_ticks_msec())


func _has_test_arg() -> bool:
	var args := OS.get_cmdline_user_args()
	for a in TEST_ARGS:
		if args.has(a):
			return true
	return false


func _reroute_to_test_scene() -> void:
	print_debug("[GameManager] 检测到测试参数，切回 %s" % TEST_SCENE)
	get_tree().change_scene_to_file(TEST_SCENE)
