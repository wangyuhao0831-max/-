extends Node3D
## DevPlayground 根控制器（场景装配层）：
##   1) 组装存档快照并响应 EventBus.save_requested（自动结算存档）；
##   2) 命令行带 --autoload-save 时在启动时载入存档（金币/声望/日/库存/unlocks）。
## 注：仅做场景↔系统的"接线"，不含业务决策（R7/R8 边界之外属装配职责）。

const AUTOLOAD_ARG := "--autoload-save"
const PREVIEW_ARG := "--tavern-preview"
const TAVERN_SCENE := "res://game/scenes/tavern/tavern.tscn"

@export var inventory_path: NodePath = ^"Player/Inventory"


func _ready() -> void:
	if OS.get_cmdline_user_args().has(PREVIEW_ARG):
		get_tree().change_scene_to_file(TAVERN_SCENE)
		return
	EventBus.save_requested.connect(_on_save_requested)
	if OS.get_cmdline_user_args().has(AUTOLOAD_ARG):
		_try_load_save()


## 响应存档请求（如 DayManager 日结算自动存档）。
func _on_save_requested(reason: StringName) -> void:
	var payload := _build_snapshot()
	payload["save_reason"] = String(reason)
	var result := SaveManager.save_file(payload)
	if result.success:
		print_debug("[RootSave] %s：%s" % [reason, result.message])
	else:
		push_warning("[RootSave] %s 失败：%s" % [reason, result.to_text()])


func _build_snapshot() -> Dictionary:
	var gold := GameState.get_balance(Transaction.TAVERN_TILL_ID)
	var inventory: Array[Dictionary] = []
	var inv := get_node_or_null(inventory_path) as Inventory
	if inv != null:
		for stack in inv.list_stacks():
			if stack.definition != null and stack.count > 0:
				inventory.append({"item_id": String(stack.definition.item_id), "count": stack.count})
	return {
		"game_version": GameManager.VERSION,
		"current_day": DayManager.day_index,
		"gold": gold,
		"reputation": DayManager.reputation,
		"inventory": inventory,
		"unlocks": DayManager.unlocks.duplicate(),
	}


func _try_load_save() -> void:
	var data := SaveManager.load_file()
	if data.is_empty():
		print_debug("[RootSave] 无可载入存档，全新开局")
		return
	var day: int = int(data.get("current_day", 1))
	var gold: int = int(data.get("gold", 0))
	var rep: int = int(data.get("reputation", 50))
	var unlocks: Variant = data.get("unlocks", {})
	if unlocks is Dictionary:
		DayManager.unlocks = unlocks.duplicate()
	DayManager.apply_day_state(day)
	DayManager.set_reputation(rep)
	GameState.set_balance(Transaction.TAVERN_TILL_ID, gold)
	var inv := get_node_or_null(inventory_path) as Inventory
	if inv != null:
		inv.clear()
		var stacks: Variant = data.get("inventory", [])
		if stacks is Array:
			for entry in stacks:
				if not (entry is Dictionary):
					continue
				var item_id := StringName(String(entry.get("item_id", "")))
				var count := int(entry.get("count", 0))
				var definition := DataRegistry.get_item(item_id)
				if definition == null:
					push_warning("[RootSave] 存档物品未注册：%s（跳过）" % item_id)
				elif count > 0:
					inv.add_item(definition, count)
	print_debug("[RootSave] 已载入：Day %d gold %d rep %d" % [day, gold, rep])
