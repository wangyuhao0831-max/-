class_name NPCStateMachine
extends RefCounted
## NPC：有限状态机（Phase 2B 最小版）。
## 状态常量（StringName）+ 合法迁移表；状态切换由 NPCController（Game Brain）驱动。
## AI 不参与状态决策（预留：后续 AI Brain 建议仅影响决策点，不改状态机结构）。

const S_ENTER_TAVERN := &"enter_tavern"
const S_FIND_SEAT := &"find_seat"
const S_WALK_TO_SEAT := &"walk_to_seat"
const S_SIT := &"sit"
const S_ORDER := &"order"
const S_WAIT_DRINK := &"wait_drink"
const S_PAY := &"pay"
const S_DRINK := &"drink"
const S_LEAVE := &"leave"

## 合法迁移表（key: from -> 允许的 to 列表）。
const _TRANSITIONS := {
	S_ENTER_TAVERN: [S_FIND_SEAT],
	S_FIND_SEAT: [S_WALK_TO_SEAT],
	S_WALK_TO_SEAT: [S_SIT],
	S_SIT: [S_ORDER],
	S_ORDER: [S_WAIT_DRINK],
	S_WAIT_DRINK: [S_PAY, S_LEAVE],  # Phase 2C：交付超时失败后顾客放弃离开
	S_PAY: [S_DRINK],
	S_DRINK: [S_LEAVE],
	S_LEAVE: [],
}

var _current: StringName = S_ENTER_TAVERN


## 初始状态（默认 enter_tavern；测试可直接指定）。
func setup(initial_state: StringName = S_ENTER_TAVERN) -> void:
	_current = initial_state


func current_state() -> StringName:
	return _current


## from 状态下是否允许迁移到 to。
func can_transition(from_state: StringName, to_state: StringName) -> bool:
	if not _TRANSITIONS.has(from_state):
		return false
	var allowed: Array = _TRANSITIONS[from_state]
	return allowed.has(to_state)


## 尝试迁移；非法迁移告警并返回 false。
func transition_to(to_state: StringName) -> bool:
	if to_state == _current:
		return true
	if not can_transition(_current, to_state):
		push_warning("NPCStateMachine: 非法迁移 %s -> %s" % [_current, to_state])
		return false
	_current = to_state
	return true


## from 状态允许的所有目标（测试/调试）。
func allowed_next(from_state: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if _TRANSITIONS.has(from_state):
		for s in _TRANSITIONS[from_state]:
			out.append(s as StringName)
	return out


## 是否为终态。
func is_terminal() -> bool:
	return _current == S_LEAVE
