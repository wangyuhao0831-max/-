class_name Transaction
extends RefCounted
## Economy：最小交易记录（Phase 2B）。
## 语义：一次金币转移的"事实记录"，随 EventBus.transaction_completed 广播；
## 账目执行由 GameState 台账（debit/credit）完成 —— 本类不做任何写操作。
## 接收方惯例：酒馆收入记到 TAVERN_TILL_ID 这个 actor 钱包。

## 酒馆钱箱 actor id（GameState 台账键；由 CustomerSpawner 启动时 ensure）。
const TAVERN_TILL_ID := &"tavern_till"

var transaction_id: StringName = &""
var from_actor_id: StringName = &""
var to_actor_id: StringName = &""
## 关联物品（可为空）。
var item_id: StringName = &""
## 金币金额（已含数量折价）。
var amount_coins: int = 0
## 关联订单（可为空）。
var order_id: StringName = &""
var executed_at_msec: int = 0


func to_text() -> String:
	return "%s: %s -> %s %d coin(s) (order=%s)" % [
		transaction_id, from_actor_id, to_actor_id, amount_coins, order_id
	]
