class_name ItemPickup
extends Interactable
## Interaction：可拾取的世界物品（灰盒版）。
## 携带一个 ItemDefinition；交互时把物品加入 actor 子树中的 Inventory 节点
## （Inventory 作为 actor 的"子节点组件"，命名查找，见 Inventory 文档）。
## 全部拾取成功则移除自身。

## 物品定义（数据驱动，来自 .tres）。
@export var item_definition: ItemDefinition = null
## 本次拾取数量。
@export var amount: int = 1


func _ready() -> void:
	prompt_verb = "拾取"
	if item_definition != null and prompt_noun.is_empty():
		prompt_noun = item_definition.display_name


func can_interact(actor: Node3D) -> bool:
	return item_definition != null and _find_inventory(actor) != null


func interact(actor: Node3D) -> void:
	if item_definition == null:
		push_warning("ItemPickup(%s): 未配置 item_definition，无法拾取" % name)
		return
	var inventory := _find_inventory(actor)
	if inventory == null:
		push_warning("ItemPickup(%s): actor 子树中未找到 Inventory" % name)
		return
	var added := inventory.add_item(item_definition, amount)
	if added == amount:
		print_debug("[ItemPickup] %s x%d -> %s" % [item_definition.item_id, amount, inventory.inventory_id])
		queue_free()
	elif added > 0:
		amount -= added
		push_warning("ItemPickup(%s): 背包已满，仅拾取 %d/%d" % [name, added, amount + added])
	else:
		push_warning("ItemPickup(%s): 背包已满，无法拾取" % name)


## 在 actor 子树中查找首个名为 Inventory 的节点（组件约定）。
func _find_inventory(actor: Node3D) -> Inventory:
	if actor == null:
		return null
	var node := actor.find_child("Inventory", true, false)
	return node as Inventory
