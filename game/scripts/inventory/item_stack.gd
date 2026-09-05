class_name ItemStack
extends Resource
## Inventory：物品堆叠（一个 ItemDefinition + 数量）。
## 运行时对象；规则：0 < count <= definition.stack_max。

var definition: ItemDefinition = null
var count: int = 0


func _init(p_definition: ItemDefinition = null, p_count: int = 1) -> void:
	definition = p_definition
	count = clampi(p_count, 0, _cap())

func item_id() -> StringName:
	if definition == null:
		return &""
	return definition.item_id


func is_full() -> bool:
	return count >= _cap()


## 剩余可容纳数量。
func space_left() -> int:
	return maxi(_cap() - count, 0)


## 尝试加入 amount，返回实际加入数量（不超上限）。
func add_up_to(amount: int) -> int:
	var added := mini(maxi(amount, 0), space_left())
	count += added
	return added


## 尝试移除 amount，返回实际移除数量（不超当前数量）。
func try_remove(amount: int) -> int:
	var removed := mini(maxi(amount, 0), count)
	count -= removed
	return removed


func _cap() -> int:
	if definition == null:
		return 0
	return definition.stack_max
