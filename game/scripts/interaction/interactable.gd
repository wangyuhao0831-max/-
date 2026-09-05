class_name Interactable
extends Node3D
## Interaction：可交互物基类（组件模式）。
## 用法：挂到带碰撞体的物理节点（StaticBody3D 等）上并实现 interact()。
## 子类只需覆写 interact(actor)，可选覆写 can_interact(actor)。

@export_group("Identity")
@export var interaction_id: StringName = &"interactable"

@export_group("Prompt")
## 提示动作动词（如 "拾取" / "打开"）。
@export var prompt_verb: String = "交互"
## 提示目标名词；留空则 fallback 到 make_prompt() 内的默认值。
@export var prompt_noun: String = ""


## 询问该目标当前是否可被 actor 交互。返回 false 时 InteractionManager 不会提示/触发。
func can_interact(_actor: Node3D) -> bool:
	return true


## 执行交互。actor 为交互发起者（通常是玩家根节点）。
func interact(_actor: Node3D) -> void:
	push_warning("Interactable(%s): interact() 未实现" % interaction_id)


## 生成当前交互提示数据。
func make_prompt() -> InteractionPrompt:
	return InteractionPrompt.new(interaction_id, prompt_verb, _resolve_noun())


func _resolve_noun() -> String:
	if not prompt_noun.is_empty():
		return prompt_noun
	return name
