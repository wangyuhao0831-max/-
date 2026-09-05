class_name ItemDefinition
extends Resource
## Inventory：物品静态定义（纯数据，.tres 配置，数据驱动）。
## 只描述"物品是什么"；数量与实例归属由 ItemStack / Inventory 管理。

@export_group("Identity")
## 全局唯一物品 ID（StringName，全项目约定）。
@export var item_id: StringName = &""
## 展示名（UI 显示用）。
@export var display_name: String = ""
## 描述文本（后续交付/任务系统使用）。
@export_multiline var description: String = ""

@export_group("Stack")
## 单格堆叠上限。
@export_range(1, 999, 1) var stack_max: int = 99

@export_group("Economy")
## 单价（金币；订单结算使用，酒馆数据）。
@export_range(0, 9999, 1) var price: int = 0


## 是否是同一物品（按 item_id 比较）。
func matches_id(p_item_id: StringName) -> bool:
	return item_id == p_item_id
