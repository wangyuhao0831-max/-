class_name Order
extends RefCounted
## Tavern：酒水订单（运行时数据，Phase 2B 最小版）。
## 生命周期：OPEN（等待交付）→ FULFILLED（已交付待收款）→ CLOSED（收款关闭）。

enum Phase { OPEN, FULFILLED, CLOSED, FAILED }

var order_id: StringName = &""
## 下单 NPC（actor id）。
var npc_id: StringName = &""
var item_id: StringName = &""
var amount: int = 1
var unit_price: int = 0
var total_price: int = 0
## 下单时座位 id（仅记录）。
var seat_id: StringName = &""
var phase: int = Phase.OPEN
var created_at_msec: int = 0
## 超时截止（GameClock.current_day_seconds 口径；OPEN 超时 → 失败）。
var expires_at_seconds: float = 0.0


func phase_text() -> String:
	match phase:
		Phase.OPEN:
			return "open"
		Phase.FULFILLED:
			return "fulfilled"
		Phase.CLOSED:
			return "closed"
		Phase.FAILED:
			return "failed"
	return "?"


func to_text() -> String:
	return "%s npc=%s item=%s x%d price=%d phase=%s" % [
		order_id, npc_id, item_id, amount, total_price, phase_text()
	]
