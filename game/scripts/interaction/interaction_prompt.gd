class_name InteractionPrompt
extends RefCounted
## Interaction：交互提示的纯数据载体（架构 R8：非 UI 类型、不含逻辑）。
## 由 Interactable.make_prompt() 生成，经 EventBus.interaction_prompt_changed 广播。

var target_id: StringName = &""
## 动作动词（如 "拾取"）。
var verb: String = ""
## 目标名称（如 "空酒瓶"）。
var noun: String = ""


func _init(p_target_id: StringName = &"", p_verb: String = "", p_noun: String = "") -> void:
	target_id = p_target_id
	verb = p_verb
	noun = p_noun


## 人类可读的一行提示（UI 可直接显示）。
func to_text() -> String:
	if noun.is_empty():
		return verb
	return "%s %s" % [verb, noun]
