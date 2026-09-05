class_name NPCProfile
extends Resource
## NPC：NPC 静态档案（纯数据，.tres 配置，数据驱动）。
## 只描述"这个 NPC 是谁/偏好什么"；运行态（位置/状态机/关系变化）属
## NPCRuntimeState（Phase 2B）。本类在 Phase 2A 即交付，供 DataRegistry
## 注册与 RuleValidator 的 npc_request_item 规则使用。

@export_group("Identity")
## 全局唯一 NPC id（StringName）。
@export var npc_id: StringName = &""
## 展示名。
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Behavior Hints")
## 请求偏好物品（订单生成/规则校验用；空 = 不限制）。
@export var preferred_item_ids: Array[StringName] = []
## 性格标签（保留：后续 AI 提示词/对话风格构建用，Phase 2 不实现）。
@export var personality_tags: Array[StringName] = []

@export_group("Relationship")
## 初始关系值（保留：relationship_delta 落点，Phase 2 不实现）。
@export var relationship_start: int = 0


## 是否偏好该物品（preferred_item_ids 为空视为不限）。
func prefers(item_id: StringName) -> bool:
	if preferred_item_ids.is_empty():
		return true
	return preferred_item_ids.has(item_id)
