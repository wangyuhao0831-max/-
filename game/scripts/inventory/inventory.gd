class_name Inventory
extends Node
## Inventory：库存容器（组件模式，作为角色的子节点挂载）。
## 容量：不限物品种类，最多 MAX_STACKS 个堆叠，每堆叠受 definition.stack_max 限制。
## 生命周期（Phase 2A）：_ready 自动向 GameState 注册（按 inventory_id），
## 退出树自动注销 —— 跨系统一律经 GameState 按 StringName 查询，禁止节点爬取。
## 事件：内容变化时发出 changed()；跨系统广播由持有者转发 EventBus（PlayerController 约定）。

signal changed()

## 本库存逻辑 ID（玩家/箱子/NPC 各自独立，StringName 唯一）。
@export var inventory_id: StringName = &"inventory"

const MAX_STACKS := 64

var _stacks: Array[ItemStack] = []


func _ready() -> void:
	GameState.register_inventory(self)


func _exit_tree() -> void:
	GameState.unregister_inventory(self)


## 加入物品，返回实际加入数量（可能小于 amount，例如容量已满）。
func add_item(definition: ItemDefinition, amount: int = 1) -> int:
	if definition == null or amount <= 0:
		return 0
	var remaining := amount
	for stack in _stacks:
		if stack.definition != null \
				and stack.definition.item_id == definition.item_id and not stack.is_full():
			remaining -= stack.add_up_to(remaining)
			if remaining <= 0:
				break
	while remaining > 0 and _stacks.size() < MAX_STACKS:
		var chunk := mini(remaining, definition.stack_max)
		_stacks.append(ItemStack.new(definition, chunk))
		remaining -= chunk
	var added := amount - remaining
	if added > 0:
		changed.emit()
	return added


## 移除物品，返回实际移除数量。
func remove_item(p_item_id: StringName, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var remaining := amount
	for i in range(_stacks.size() - 1, -1, -1):
		var stack := _stacks[i]
		if stack.definition != null and stack.definition.matches_id(p_item_id):
			remaining -= stack.try_remove(remaining)
			if stack.count <= 0:
				_stacks.remove_at(i)
			if remaining <= 0:
				break
	var removed := amount - remaining
	if removed > 0:
		changed.emit()
	return removed


## 指定物品的当前总量。
func get_count(p_item_id: StringName) -> int:
	var total := 0
	for stack in _stacks:
		if stack.definition != null and stack.definition.matches_id(p_item_id):
			total += stack.count
	return total


## 是否至少持有 amount 个指定物品。
func has(p_item_id: StringName, amount: int = 1) -> bool:
	return get_count(p_item_id) >= amount


## 还能再容纳多少件该物品（同 ID 未满堆叠余量 + 空槽新增堆叠容量）。
## 供 RuleValidator 容量侧校验（单一事实来源，与 add_item 合并语义一致）。
func max_addable(definition: ItemDefinition) -> int:
	if definition == null:
		return 0
	var space := 0
	for stack in _stacks:
		if stack.definition != null and stack.definition.item_id == definition.item_id:
			space += stack.space_left()
	space += (MAX_STACKS - _stacks.size()) * definition.stack_max
	return space


## 是否可接收 amount 件该物品（RuleValidator / 内部使用）。
func can_receive(definition: ItemDefinition, amount: int = 1) -> bool:
	return amount > 0 and amount <= max_addable(definition)


## 快照当前堆叠列表（浅拷贝，安全只读遍历）。
func list_stacks() -> Array[ItemStack]:
	return _stacks.duplicate()


## 当前堆叠数量。
func stack_count() -> int:
	return _stacks.size()


## 清空库存。
func clear() -> void:
	if _stacks.is_empty():
		return
	_stacks.clear()
	changed.emit()
