extends Node
## Save：最小存档服务（autoload）—— 纯 JSON 文件 I/O。
## 存档内容（快照由场景侧组装并调用 save_file）：
##   game_version / current_day / gold / reputation / inventory / unlocks
## 注：无 class_name（autoload 名 = 全局访问符号）。

const SAVE_PATH := "user://arcane_tavern_save_v1.json"

## 写入存档；payload 任意可 JSON 化的字典。失败返回 io_error。
func save_file(payload: Dictionary) -> InteractionResult:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return InteractionResult.failed(
			InteractionResult.CODE_IO_ERROR, &"save_game", &"", &"",
			"无法打开存档文件：%s" % SAVE_PATH)
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	print_debug("[SaveManager] saved -> %s" % SAVE_PATH)
	return InteractionResult.ok(&"save_game", &"", &"", "已保存", {"path": SAVE_PATH})


## 读取存档；文件不存在返回空字典（首跑正常），解析失败告警并返回空字典。
func load_file() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		print_debug("[SaveManager] 无存档（首跑）")
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: 无法打开存档 %s" % SAVE_PATH)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_warning("SaveManager: 存档解析失败（%s）" % SAVE_PATH)
		return {}
	return parsed as Dictionary


## 删除存档（测试隔离用）。
func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if err != OK:
			push_warning("SaveManager: 删除存档失败 err=%d" % err)
		else:
			print_debug("[SaveManager] save cleared")
