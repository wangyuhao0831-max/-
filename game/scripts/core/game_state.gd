extends Node
## Core：世界运行状态（autoload）。规则：负责"注册与查询"，不持有玩法决策——
## 禁止演变为 God Object。本类只做两件事：
##  1) 记录运行阶段（boot → playing），由 GameManager 驱动；
##  2) 维护 Inventory / Actor 注册表（StringName ID），供系统按 ID 查询。
## 注：无 class_name —— 以 autoload 名 GameState 作为全局访问符号（Godot 4.7 规则）。

const PHASE_BOOT := &"boot"
const PHASE_PLAYING := &"playing"

## 当前运行阶段。
var game_phase: StringName = PHASE_BOOT

# inventory_id -> Inventory（节点组件退出树时自动注销）。
var _inventories: Dictionary[StringName, Inventory] = {}
# actor_id -> inventory_id。
var _actor_inventory: Dictionary[StringName, StringName] = {}
# inventory_id -> 最近登记的 actor_id（反查表，便于"拿到 Inventory 推导 actor"）。
var _inventory_actor: Dictionary[StringName, StringName] = {}


## 由 GameManager 在启动引导完成时调用：boot → playing。
func begin_playing() -> void:
	if game_phase != PHASE_PLAYING:
		print_debug("[GameState] phase: %s -> %s" % [game_phase, PHASE_PLAYING])
		game_phase = PHASE_PLAYING


# --- Inventory 注册 ---

## 注册库存（重复 inventory_id 忽略并告警）。成功返回 true。
func register_inventory(inventory: Inventory) -> bool:
	if inventory == null or inventory.inventory_id == &"":
		push_warning("GameState: 拒绝注册空库存")
		return false
	if _inventories.has(inventory.inventory_id):
		push_warning("GameState: 重复注册 inventory_id=%s（保留先注册者）" % inventory.inventory_id)
		return false
	_inventories[inventory.inventory_id] = inventory
	print_debug("[GameState] register inventory: %s" % inventory.inventory_id)
	return true


## 注销库存（节点退出树时调用；同时清理指向该库存的 actor 映射）。
func unregister_inventory(inventory: Inventory) -> void:
	if inventory == null:
		return
	var inventory_id := inventory.inventory_id
	_inventories.erase(inventory_id)
	_inventory_actor.erase(inventory_id)
	for actor_id: StringName in _actor_inventory.keys():
		if _actor_inventory[actor_id] == inventory_id:
			_actor_inventory.erase(actor_id)


## 按 inventory_id 查询库存；未注册返回 null。
func get_inventory(inventory_id: StringName) -> Inventory:
	return _inventories.get(inventory_id, null)


func has_inventory(inventory_id: StringName) -> bool:
	return _inventories.has(inventory_id)


# --- Actor 注册 ---

## 注册 actor -> inventory 关联（actor 如 &"player"、NPC id）。
## 允许 inventory 尚未注册（防御：注销/空库存场景）；后续查询会给出对应结果码。
func register_actor(actor_id: StringName, inventory_id: StringName) -> bool:
	if actor_id == &"":
		push_warning("GameState: 拒绝注册空 actor_id")
		return false
	_actor_inventory[actor_id] = inventory_id
	if inventory_id != &"":
		# 同一库存可被多 actor 引用（共享仓库）；反查保留最近一次写入。
		_inventory_actor[inventory_id] = actor_id
	print_debug("[GameState] register actor: %s -> inventory %s" % [actor_id, inventory_id])
	return true


## 注销 actor 关联。
func unregister_actor(actor_id: StringName) -> void:
	if not _actor_inventory.has(actor_id):
		return
	var inventory_id := _actor_inventory[actor_id]
	_actor_inventory.erase(actor_id)
	if inventory_id != &"" and _inventory_actor.get(inventory_id, &"") == actor_id:
		_inventory_actor.erase(inventory_id)


func has_actor(actor_id: StringName) -> bool:
	return _actor_inventory.has(actor_id)


## actor 的库存（按 actor->inventory->实例 两级解析）；缺失返回 null。
func get_inventory_for_actor(actor_id: StringName) -> Inventory:
	var inventory_id: StringName = _actor_inventory.get(actor_id, &"")
	if inventory_id == &"":
		return null
	return _inventories.get(inventory_id, null)


## 反查：持有某库存的 actor id（最近登记）；无返回 &""。
func get_actor_id_for_inventory(inventory_id: StringName) -> StringName:
	return _inventory_actor.get(inventory_id, &"")


## 当前注册规模（调试信息）。
func debug_summary() -> String:
	return "inventories=%d actors=%d" % [_inventories.size(), _actor_inventory.size()]
