class_name TavernSeat
extends Node3D
## Tavern：座位（数据组件，挂在场景中的椅子节点上）。
## 职责：占用状态（reserved_by）+ 站立/入座点（park_position）。
## 运行时自动加入 "tavern_seats" 组，由 SeatManager 收集。

## 座位 id（StringName 唯一；测试/存档用）。
@export var seat_id: StringName = &"seat"
## 顾客站立点相对座位的偏移（本地空间，未旋转场景下 = 椅子正面方向）。
@export var park_offset: Vector3 = Vector3(0.0, 0.0, 0.6)

var reserved_by: StringName = &""


func _ready() -> void:
	if seat_id == &"":
		seat_id = StringName(name)
	add_to_group("tavern_seats")


func is_free() -> bool:
	return reserved_by == &""


func is_reserved_by(npc_id: StringName) -> bool:
	return reserved_by == npc_id


## 预占座位；已被占用返回 false。
func reserve(npc_id: StringName) -> bool:
	if npc_id == &"" or not is_free():
		return false
	reserved_by = npc_id
	print_debug("[TavernSeat] %s 被 %s 占用" % [seat_id, npc_id])
	return true


## 释放座位。
func release() -> void:
	if reserved_by != &"":
		print_debug("[TavernSeat] %s 释放（原 %s）" % [seat_id, reserved_by])
	reserved_by = &""


## 顾客入座站立点（世界坐标）。
func park_position() -> Vector3:
	return global_position + park_offset
