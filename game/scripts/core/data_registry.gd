extends Node
## Core：数据驱动注册表（autoload）。
## 机制：Resource 按 "category + StringName id" 注册/查询；类别常量如下。
##   item / npc_profile 在启动时自动扫描对应资源目录（boot scan）；
##   recipe / quest 为预留类别 —— 交付时用同一套 register_resource/get_resource
##   即可接入，无需修改本类（扩展接口）。
## 依赖方向：本类引用领域 Resource 类型（class_name 全局符号，非文件级 import，
## 与 EventBus 同约定）。注：无 class_name（autoload 名 = 全局访问符号）。

## 类别常量。
const CATEGORY_ITEM := &"item"
const CATEGORY_NPC_PROFILE := &"npc_profile"
## 预留：Recipe/Quest（Phase 2C+，本阶段不扫描、不校验内容）。
const CATEGORY_RECIPE := &"recipe"
const CATEGORY_QUEST := &"quest"

## 启动扫描目录（category -> res:// 目录）。
const BOOT_SCAN_DIRS := {
	CATEGORY_ITEM: "res://game/resources/items",
	CATEGORY_NPC_PROFILE: "res://game/resources/npcs",
}

# category -> (id -> Resource)。注意：Godot 不支持嵌套 typed 集合，
# 内层用普通 Dictionary（读时经本类强类型接口收口）。
var _resources: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	for category: StringName in BOOT_SCAN_DIRS.keys():
		var dir_path := BOOT_SCAN_DIRS[category] as String
		if DirAccess.dir_exists_absolute(dir_path):
			_scan_category(category, dir_path)
		else:
			push_warning("DataRegistry: 扫描目录不存在 %s" % dir_path)
	print_debug("[DataRegistry] boot scan: %s" % summary())


# --- 通用注册/查询（Recipe/Quest 等预留类别也走这里） ---

## 注册资源；重复 (category, id) 忽略并告警。成功返回 true。
func register_resource(category: StringName, id: StringName, resource: Resource) -> bool:
	if category == &"" or id == &"" or resource == null:
		push_warning("DataRegistry: 非法注册（category/id/resource 不可为空）")
		return false
	if not _resources.has(category):
		_resources[category] = {}
	var table: Dictionary = _resources[category]
	if table.has(id):
		push_warning("DataRegistry: 重复注册 [%s]%s（保留先注册者）" % [category, id])
		return false
	table[id] = resource
	_resources[category] = table
	print_debug("[DataRegistry] register [%s] %s" % [category, id])
	return true


## 注销资源；不存在时静默。
func unregister_resource(category: StringName, id: StringName) -> void:
	if not _resources.has(category):
		return
	var table: Dictionary = _resources[category]
	table.erase(id)
	if table.is_empty():
		_resources.erase(category)
	else:
		_resources[category] = table


## 通用查询：未注册返回 null。
func get_resource(category: StringName, id: StringName) -> Resource:
	if not _resources.has(category):
		return null
	return _resources[category].get(id, null)


func has_resource(category: StringName, id: StringName) -> bool:
	return get_resource(category, id) != null


## 某类别当前注册数。
func count(category: StringName) -> int:
	if not _resources.has(category):
		return 0
	return _resources[category].size()


## 某类别全部 id 列表。
func list_ids(category: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if not _resources.has(category):
		return out
	for key in _resources[category].keys():
		out.append(StringName(key))
	return out


# --- 物品（强类型便捷接口） ---

func register_item(item: ItemDefinition) -> bool:
	if item == null:
		return false
	return register_resource(CATEGORY_ITEM, item.item_id, item)


func get_item(item_id: StringName) -> ItemDefinition:
	var res := get_resource(CATEGORY_ITEM, item_id)
	return res as ItemDefinition


func has_item(item_id: StringName) -> bool:
	return get_item(item_id) != null


# --- NPC 档案（强类型便捷接口） ---

func register_npc_profile(profile: NPCProfile) -> bool:
	if profile == null:
		return false
	return register_resource(CATEGORY_NPC_PROFILE, profile.npc_id, profile)


func get_npc_profile(npc_id: StringName) -> NPCProfile:
	var res := get_resource(CATEGORY_NPC_PROFILE, npc_id)
	return res as NPCProfile


func has_npc_profile(npc_id: StringName) -> bool:
	return get_npc_profile(npc_id) != null


# --- 内部 ---

func _scan_category(category: StringName, dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("DataRegistry: 无法打开 %s" % dir_path)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".tres"):
			var full_path := dir_path.path_join(file)
			var res: Resource = load(full_path)
			if res == null:
				push_warning("DataRegistry: 加载失败 %s" % full_path)
			else:
				var id := _extract_id(category, res)
				if id == &"":
					push_warning("DataRegistry: %s 无有效 id，跳过" % full_path)
				else:
					register_resource(category, id, res)
		file = dir.get_next()
	dir.list_dir_end()


## 从资源中取类别主键（typed 便捷登记用）。
func _extract_id(category: StringName, res: Resource) -> StringName:
	match category:
		CATEGORY_ITEM:
			if res is ItemDefinition:
				return (res as ItemDefinition).item_id
		CATEGORY_NPC_PROFILE:
			if res is NPCProfile:
				return (res as NPCProfile).npc_id
	return &""


## 注册统计（调试）。
func summary() -> String:
	var parts: Array[String] = []
	for category: StringName in _resources.keys():
		parts.append("%s=%d" % [category, _resources[category].size()])
	return ", ".join(parts)
