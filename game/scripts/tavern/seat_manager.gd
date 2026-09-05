class_name SeatManager
extends Node
## Tavern：座位管理器。
## 收集组 "tavern_seats" 中的 TavernSeat（按节点名排序保证确定性），
## 提供空闲座位查询与按 NPC 释放。

var _seats: Array[TavernSeat] = []


func _ready() -> void:
	# 延迟收集：确保同场景所有座位已完成 _ready 并加入组。
	call_deferred("_collect_seats")


## 手动注册（非组内座位也可加入；重复忽略）。
func register_seat(seat: TavernSeat) -> bool:
	if seat == null or _seats.has(seat):
		return false
	_seats.append(seat)
	_seats.sort_custom(_seat_less)
	return true


func _collect_seats() -> void:
	_seats.clear()
	for node in get_tree().get_nodes_in_group("tavern_seats"):
		var seat := node as TavernSeat
		if seat != null:
			register_seat(seat)
	var names: Array[String] = []
	for seat in _seats:
		names.append("%s(%s)" % [seat.name, seat.seat_id])
	print_debug("[SeatManager] 收集到 %d 个座位：%s" % [_seats.size(), ", ".join(names)])


func _seat_less(a: TavernSeat, b: TavernSeat) -> bool:
	return a.name < b.name


func total_seats() -> int:
	return _seats.size()


## 空闲座位数。
func free_seat_count() -> int:
	var n := 0
	for seat in _seats:
		if seat.is_free():
			n += 1
	return n


## 首个空闲座位（名字序确定）；无则 null。
func find_free_seat() -> TavernSeat:
	for seat in _seats:
		if seat.is_free():
			return seat
	return null


func seat_by_id(seat_id: StringName) -> TavernSeat:
	for seat in _seats:
		if seat.seat_id == seat_id:
			return seat
	return null


## 释放该 NPC 占用的所有座位（防御性清理）。
func release_seat_of(npc_id: StringName) -> void:
	for seat in _seats:
		if seat.is_reserved_by(npc_id):
			seat.release()
